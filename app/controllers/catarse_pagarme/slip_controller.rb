require 'weekdays'

module CatarsePagarme
  class SlipController < CatarsePagarme::ApplicationController

    def create
      transaction = SlipTransaction.new(permitted_attributes, payment).charge!

      render json: { boleto_url: transaction.boleto_url, payment_status: transaction.status }
    rescue PagarMe::PagarMeError => e
      render json: { boleto_url: nil, payment_status: 'failed', message: e.message }
    end

    def update
      transaction = SlipTransaction.new(permitted_attributes, payment).charge!
      render text: transaction.boleto_url
    end

    protected

    def slip_attributes
      expiration_date = (CatarsePagarme.configuration.slip_week_day_interval || 2).weekdays_from_now
      {
        payment_method: 'boleto',
        boleto_expiration_date: expiration_date,
        amount: delegator.value_for_transaction,
        postback_url: ipn_pagarme_index_url(host: CatarsePagarme.configuration.host,
                                            subdomain: CatarsePagarme.configuration.subdomain,
                                            protocol: CatarsePagarme.configuration.protocol),
        customer: {
          email: payment.user.email,
          name: payment.user.name
        },
        metadata: metadata_attributes
      }.update({ user: params[:user] })
    end

    def permitted_attributes
      attrs = ActionController::Parameters.new(slip_attributes)
      attrs.permit(:boleto_expiration_date, :payment_method, :amount, :postback_url, metadata: [:key], customer: [:name, :email],
        user: [
          bank_account_attributes: [
            :bank_id, :account, :account_digit, :agency,
            :agency_digit, :owner_name, :owner_document
          ]
        ])
    end

  end
end
