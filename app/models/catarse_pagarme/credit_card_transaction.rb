module CatarsePagarme
  class CreditCardTransaction < TransactionBase

    def charge!
      save_card = self.attributes.delete(:save_card)
      
      #hash_attributes = JSON.parse(self.attributes.to_json)
      #hash_attributes["customer"]["document_number"]="92545278157"
      #addr={"street" => "Av. Brigadeiro Faria Lima", "neighborhood" => "Jardim Paulistano", "zipcode" => "01452000", "street_number" => "2941"}
      #ph={"ddd" => "11", "number" => "30713261"} 
      #hash_attributes["address"]=addr
      #hash_attributes["phone"]=ph

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
      byebug
      #self.transaction = PagarMe::Transaction.new(self.attributes)
      #self.transaction = PagarMe::Transaction.new(hash_attributes)
      self.transaction = PagarMe::Transaction.new(p)
      self.transaction.charge

      change_payment_state

      if self.transaction.status == 'refused'
        raise ::PagarMe::PagarMeError.new(I18n.t('projects.contributions.edit.transaction_error'))
      end

      save_user_credit_card if save_card
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
