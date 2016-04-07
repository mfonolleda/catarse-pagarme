module CatarsePagarme
  class PaymentDelegator
    attr_accessor :payment, :transaction
    include FeeCalculatorConcern

    def initialize(payment)
      configure_pagarme
      self.payment = payment
    end

    def change_status_by_transaction(transactin_status)
      case transactin_status
      when 'paid', 'authorized' then
        if payment.refunded? || payment.pending_refund?
          payment.invalid_refund
        elsif !self.payment.paid?
          self.payment.pay
        end
      when 'refunded' then
        self.payment.refund unless self.payment.refunded?
      when 'refused' then
        self.payment.refuse unless self.payment.refused?
      end
    end

    def update_transaction
      fill_acquirer_data
      payment.installment_value = (value_for_installment / 100.0).to_f
      payment.gateway_fee = get_fee
      payment.save!
    end

    def fill_acquirer_data
      if payment.gateway_data.nil? || payment.gateway_data["acquirer_name"].nil? || payment.gateway_data["acquirer_tid"].nil?
        data = payment.gateway_data || {}
        payment.gateway_data = data.merge({
          acquirer_name: transaction.acquirer_name,
          acquirer_tid: transaction.tid,
          card_brand: transaction.try(:card_brand)
        })
        payment.save
      end
    end

    def refund
      if payment.is_credit_card?
        transaction.refund
      else
        transaction.refund(bank_account_attributes)
      end
    end

    def value_for_transaction
      (self.payment.value * 100).to_i
    end

    def value_with_installment_tax(installment)
      current_installment = get_installment(installment)

      if current_installment.present?
        current_installment['amount']
      else
        value_for_transaction
      end
    end

    def value_for_installment(installment = transaction.installments || 0)
      get_installment(installment).try(:[], "installment_amount")
    end

    def transaction
      @transaction ||= ::PagarMe::Transaction.find_by_id(self.payment.gateway_id)
      if @transaction.kind_of?(Array)
        @transaction.last
      else
        @transaction
      end
    end

    def get_installment(installment_number)
      installment = get_installments['installments'].select do |_installment|
        !_installment[installment_number.to_s].nil?
      end

      installment[installment_number.to_s]
    end

    def get_installments
      @installments ||= PagarMe::Transaction.calculate_installments({
        amount: self.value_for_transaction,
        interest_rate: CatarsePagarme.configuration.interest_rate
      })
    end

    # Transfer payment amount to payer bank account via transfers API
    # Params:
    # +authorized_by+:: +User+ object that authorize this transfer
    def transfer_funds(authorized_by)
      raise 'must be admin to perform this action' unless authorized_by.try(:admin?)

      bank_account = PagarMe::BankAccount.new(bank_account_attributes.delete(:bank_account))
      bank_account.create
      raise "unable to create an bank account" unless bank_account.id.present?

      transfer = PagarMe::Transfer.new({
        bank_account_id: bank_account.id,
        amount: value_for_transaction
      })
      transfer.create

      payment.payment_transfers.create!({
        user: authorized_by,
        transfer_id: transfer.id,
        transfer_data: transfer.to_json
      })
    end

    protected

    def bank_account_attributes
      bank = payment.user.bank_account

      {
        bank_account: {
          bank_code: (bank.bank_code || bank.name),
          agencia: bank.agency,
          agencia_dv: bank.agency_digit,
          conta: bank.account,
          conta_dv: bank.account_digit,
          legal_name: bank.owner_name,
          document_number: bank.owner_document
        }
      }
    end

    def configure_pagarme
      ::PagarMe.api_key = CatarsePagarme.configuration.api_key
    end
  end
end
