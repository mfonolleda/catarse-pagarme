module CatarsePagarme
  class CreditCardsController < CatarsePagarme::ApplicationController

    #Creates a new credit card transaction by invoking a new CreditCardTransaction object and passing the credit card attributes as a hash and calling the payment function in the Application Controller. The payment method calls the PaymentEngines class within the Catarse App (lib folder) which creates and returns a Payment object and obtains the contribution information.	  
    #The create method is called by the Jquery script Credit_card.js with an Ajax POST.
    def create
      transaction = CreditCardTransaction.new(credit_card_attributes, payment).charge!

      render json: { payment_status: transaction.status }
    rescue Exception => e
      render json: { payment_status: 'failed', message: e.message }
    end

    protected

    #Creates the json data required to create a new transaction with Pagarme. Please note that some customer data is missing for antifraud transactions...
    def credit_card_attributes
      hash = {
        payment_method: 'credit_card',
        amount: delegator.value_with_installment_tax(get_installment),
        postback_url: ipn_pagarme_index_url(host: CatarsePagarme.configuration.host,
                                            subdomain: CatarsePagarme.configuration.subdomain,
                                            protocol: CatarsePagarme.configuration.protocol),
        installments: get_installment,
        customer: {
          email: payment.user.email,
          name: payment.user.name
        },
        metadata: metadata_attributes
      }

      if params[:card_hash].present?
        hash[:card_hash] = params[:card_hash]
      else
        hash[:card_id] = params[:card_id]
      end

      if params[:save_card] === "true"
        hash[:save_card] = true
      end

      hash
    end

    def get_installment
      if payment.value.to_f < CatarsePagarme.configuration.minimum_value_for_installment.to_f
        1
      elsif params[:payment_card_installments].to_i > 0
        params[:payment_card_installments].to_i
      else
        1
      end
    end

  end
end
