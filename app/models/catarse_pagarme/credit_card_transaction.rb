module CatarsePagarme
  class CreditCardTransaction < TransactionBase

    def charge!
      #This function is called by the CreditCardController by creating a new CreditCardTransaction object and calling the charge method. When creating the object, the attributes and payment variables are passed, which are part of the parent class TransactionBase	    
      #This flag tracks whether the card must be saved or not
      save_card = self.attributes.delete(:save_card)
      
      #hash_attributes = JSON.parse(self.attributes.to_json)
      #hash_attributes["customer"]["document_number"]="92545278157"
      #addr={"street" => "Av. Brigadeiro Faria Lima", "neighborhood" => "Jardim Paulistano", "zipcode" => "01452000", "street_number" => "2941"}
      #ph={"ddd" => "11", "number" => "30713261"} 
      #hash_attributes["address"]=addr
      #hash_attributes["phone"]=ph

      #Reconstruct the hash to add some parameters that Pagar.me is requesting with the test api key.
      p = {
    	:amount => nil,
    	:card_hash => nil,
    	:customer => {
        	:name => nil,
        	:document_number => "92545278157",
        	:email => nil,
        	:address => {
            		:street => "Av. Brigadeiro Faria Lima",
            		:neighborhood => "Jardim Paulistano",
            		:zipcode => "01452000",
            		:street_number => "2941",
            		:complementary => "8º andar"
        		},
        	:phone => {
            		:ddd => "11",
            		:number => "30713261"
        		}
    		},
	:payment_method => nil,
	:postback_url => nil,
	:installments => nil,
	:metadata => nil,
	:card_id => nil
	}	
      
      p[:card_hash]=self.attributes[:card_hash]
      p[:amount]=self.attributes[:amount]
      p[:customer][:name]=self.attributes[:customer][:name]
      p[:customer][:email]=self.attributes[:customer][:email]
      p[:payment_method]=self.attributes[:payment_method]
      p[:postback_url]=self.attributes[:postback_url]
      p[:installments]=self.attributes[:installments]
      p[:metadata]=self.attributes[:metadata]
      p[:card_id]=self.attributes[:card_id]
      
      #self.transaction = PagarMe::Transaction.new(self.attributes)

      #Here the code is creating a new Pagarme transaction and executing the function to proces a new transaction. The transaction variable is defined in the TransactionBase parent class. 
      #transaction.charge returns a json string that includes status (paid or refused), id, etc. See the pagar.me API reference.
      self.transaction = PagarMe::Transaction.new(p)
      self.transaction.charge

      #This is a funcion within the parent class TransactionBase. This function saves some payment info and status...no entirely clear. It also uses the payment delegator model...
      change_payment_state

      if self.transaction.status == 'refused'
        raise ::PagarMe::PagarMeError.new(I18n.t('projects.contributions.edit.transaction_error'))
      end

      #In case the credit card needs saving the save_user_credit_card function is called which creates a credit_card object (which belongs to the user class), fills the data and saves it.
      save_user_credit_card if save_card

      #The funcion returns de transaction...
      self.transaction
    end

    def save_user_credit_card
      card = self.transaction.card

      credit_card = self.user.credit_cards.find_or_initialize_by(card_key: card.id)
      credit_card.last_digits = card.last_digits
      credit_card.card_brand = card.brand

      credit_card.save!
    end

  end
end
