require 'rails_helper'

describe 'EPP Contact', epp: true do
  let(:server) { Epp::Server.new({server: 'localhost', tag: 'gitlab', password: 'ghyt9e4fu', port: 701}) }

  context 'with valid user' do
    before(:each) { Fabricate(:epp_user) }

    # incomplete
    it 'creates a contact' do
      response = epp_request('contacts/create.xml')
      expect(response[:result_code]).to eq('1000')
      expect(response[:msg]).to eq('Command completed successfully')
      expect(response[:clTRID]).to eq('ABC-12345')

      expect(Contact.count).to eq(1)
    end

    it 'updates a contact with same ident' do
      Fabricate(:contact)
      response = epp_request('contacts/create.xml')
      expect(response[:result_code]).to eq('1000')
      expect(response[:msg]).to eq('Command completed successfully')
      expect(response[:clTRID]).to eq('ABC-12345')

      expect(Contact.first.name).to eq("John Doe")

      expect(Contact.count).to eq(1)
    end
    #TODO tests for missing/invalid/etc ident

    it 'deletes contact' do
      Fabricate(:contact)
      response = epp_request('contacts/delete.xml')
      expect(response[:result_code]).to eq('1000')
      expect(response[:msg]).to eq('Command completed successfully')
      expect(response[:clTRID]).to eq('ABC-12345')

      expect(Contact.count).to eq(0)
    end

    it 'deletes an nil object' do
      response = epp_request('contacts/delete.xml')
      expect(response[:result_code]).to eq('2303')
      expect(response[:msg]).to eq('Object does not exist')
    end

  end

end
