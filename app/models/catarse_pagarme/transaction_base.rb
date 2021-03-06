module CatarsePagarme
  class TransactionBase
    attr_accessor :attributes, :payment,
      :transaction, :user

    def initialize(attributes, payment)
      self.attributes = attributes
      self.payment = payment
      self.user = payment.user
    end

    def change_payment_state
      self.payment.update_attributes(attributes_to_payment)
      self.payment.save!
      delegator.update_transaction #saves info into transaction. See model payment_delegator.rb
      self.payment.payment_notifications.create(contribution_id: self.payment.contribution_id, extra_data: self.transaction.to_json)
      delegator.change_status_by_transaction(self.transaction.status) #updates some payment status info...not clear. See model payment_delegator.rb
    end

    def payment_method
      PaymentType::CREDIT_CARD
    end

    def attributes_to_payment
      {
        payment_method: payment_method,
        gateway_id: self.transaction.id,
        gateway: 'Pagarme',
        gateway_data: self.transaction.to_json,
        installments: default_installments
      }
    end

    def default_installments
      (self.transaction.installments || 1)
    end

    def delegator
      self.payment.pagarme_delegator
    end

  end
end
