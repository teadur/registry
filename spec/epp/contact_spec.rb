require 'rails_helper'

describe 'EPP Contact', epp: true do
  let(:server) { Epp::Server.new({ server: 'localhost', tag: 'gitlab', password: 'ghyt9e4fu', port: 701 }) }

  context 'with valid user' do
    before(:each) do
      Fabricate(:epp_user)
      Fabricate(:domain_validation_setting_group)
    end
    context 'create command' do

      it 'fails if request is invalid' do
        response = epp_request(contact_create_xml({ authInfo: [false], addr: { cc: false, city: false } }), :xml)

        expect(response[:results][0][:result_code]).to eq('2003')
        expect(response[:results][1][:result_code]).to eq('2003')
        expect(response[:results][2][:result_code]).to eq('2003')

        expect(response[:results][0][:msg]).to eq('Required parameter missing: pw')
        expect(response[:results][1][:msg]).to eq('Required parameter missing: city')
        expect(response[:results][2][:msg]).to eq('Required parameter missing: cc')
        expect(response[:results].count).to eq 3
      end

      it 'successfully creates a contact' do
        response = epp_request(contact_create_xml, :xml)

        expect(response[:result_code]).to eq('1000')
        expect(response[:msg]).to eq('Command completed successfully')
        expect(response[:clTRID]).to eq('ABC-12345')
        expect(Contact.first.created_by_id).to eq 1
        expect(Contact.first.updated_by_id).to eq nil

        expect(Contact.count).to eq(1)

        expect(Contact.first.international_address.org_name).to eq('Example Inc.')
        expect(Contact.first.ident).to eq '37605030299'
        expect(Contact.first.ident_type).to eq 'op'

        expect(Contact.first.international_address.street).to eq('123 Example Dr.')
        expect(Contact.first.international_address.street2).to eq('Suite 100')
        expect(Contact.first.international_address.street3).to eq nil
      end

      it 'successfully creates contact with 2 addresses' do
        response = epp_request('contacts/create_with_two_addresses.xml')

        expect(response[:result_code]).to eq('1000')

        expect(Contact.count).to eq(1)
        expect(Contact.first.address).to_not eq Contact.first.local_address
        expect(Address.count).to eq(2)
        expect(LocalAddress.count).to eq(1)
      end

      it 'returns result data upon success' do
        response = epp_request(contact_create_xml, :xml)

        expect(response[:result_code]).to eq('1000')
        expect(response[:msg]).to eq('Command completed successfully')

        id =  response[:parsed].css('resData creData id').first
        cr_date =  response[:parsed].css('resData creData crDate').first

        expect(id.text).to eq('sh8013')
        # 5 seconds for what-ever weird lag reasons might happen
        expect(cr_date.text.to_time).to be_within(5).of(Time.now)

      end

      it 'does not create duplicate contact' do
        Fabricate(:contact, code: 'sh8013')

        response = epp_request(contact_create_xml, :xml)

        expect(response[:result_code]).to eq('2302')
        expect(response[:msg]).to eq('Contact id already exists')

        expect(Contact.count).to eq(1)
      end
    end

    context 'update command' do
      it 'fails if request is invalid' do
        response = epp_request('contacts/update_missing_attr.xml')

        expect(response[:results][0][:result_code]).to eq('2003')
        expect(response[:results][0][:msg]).to eq('Required parameter missing: add, rem or chg')
        expect(response[:results][1][:result_code]).to eq('2003')
        expect(response[:results][1][:msg]).to eq('Required parameter missing: id')
        expect(response[:results].count).to eq 2
      end

      it 'fails with wrong authentication info' do
        Fabricate(:contact, code: 'sh8013', auth_info: 'secure_password')

        response = epp_request('contacts/update.xml')

        expect(response[:msg]).to eq('Authorization error')
        expect(response[:result_code]).to eq('2201')
      end

      it 'stamps updated_by succesfully' do
        Fabricate(:contact, code: 'sh8013')

        expect(Contact.first.updated_by_id).to be nil

        epp_request(contact_update_xml, :xml)

        expect(Contact.first.updated_by_id).to eq 1
      end

      it 'is succesful' do
        Fabricate(:contact, created_by_id: 1, email: 'not_updated@test.test', code: 'sh8013', auth_info: '2fooBAR')
        response = epp_request('contacts/update.xml')

        expect(response[:msg]).to eq('Command completed successfully')
        expect(Contact.first.name).to eq('John Doe')
        expect(Contact.first.email).to eq('jdoe@example.com')
        expect(Contact.first.ident).to eq('J836954')
        expect(Contact.first.ident_type).to eq('passport')
      end

      it 'returns phone and email error' do
        Fabricate(:contact, created_by_id: 1, email: 'not_updated@test.test', code: 'sh8013', auth_info: '2fooBAR')
        # response = epp_request(contact_update_xml( { chg: { email: "qwe", phone: "123qweasd" } }), :xml)
        response = epp_request('contacts/update_with_errors.xml')

        expect(response[:results][0][:result_code]).to eq('2005')
        expect(response[:results][0][:msg]).to eq('Phone nr is invalid')

        expect(response[:results][1][:result_code]).to eq('2005')
        expect(response[:results][1][:msg]).to eq('Email is invalid')
      end
    end

    context 'delete command' do
      it 'fails if request is invalid' do
        response = epp_request('contacts/delete_missing_attr.xml')

        expect(response[:results][0][:result_code]).to eq('2003')
        expect(response[:results][0][:msg]).to eq('Required parameter missing: id')
        expect(response[:results].count).to eq 1
      end

      it 'deletes contact' do
        Fabricate(:contact, code: 'dwa1234')
        response = epp_request('contacts/delete.xml')
        expect(response[:result_code]).to eq('1000')
        expect(response[:msg]).to eq('Command completed successfully')
        expect(response[:clTRID]).to eq('ABC-12345')

        expect(Contact.count).to eq(0)
      end

      it 'returns error if obj doesnt exist' do
        response = epp_request('contacts/delete.xml')
        expect(response[:result_code]).to eq('2303')
        expect(response[:msg]).to eq('Object does not exist')
      end

      it 'fails if contact has associated domain' do
        Fabricate(:domain, owner_contact: Fabricate(:contact, code: 'dwa1234'))
        expect(Domain.first.owner_contact.address.present?).to be true
        response = epp_request('contacts/delete.xml')

        expect(response[:result_code]).to eq('2305')
        expect(response[:msg]).to eq('Object association prohibits operation')

        expect(Domain.first.owner_contact.present?).to be true

      end
    end

    context 'check command' do
      it 'fails if request is invalid' do
        response = epp_request(contact_check_xml(ids: [false]), :xml)

        expect(response[:results][0][:result_code]).to eq('2003')
        expect(response[:results][0][:msg]).to eq('Required parameter missing: id')
        expect(response[:results].count).to eq 1
      end

      it 'returns info about contact availability' do
        Fabricate(:contact, code: 'check-1234')

        response = epp_request(contact_check_xml(ids: [{ id: 'check-1234' }, { id: 'check-4321' }]), :xml)

        expect(response[:result_code]).to eq('1000')
        expect(response[:msg]).to eq('Command completed successfully')
        ids = response[:parsed].css('resData chkData id')

        expect(ids[0].attributes['avail'].text).to eq('0')
        expect(ids[1].attributes['avail'].text).to eq('1')

        expect(ids[0].text).to eq('check-1234')
        expect(ids[1].text).to eq('check-4321')
      end
    end

    context 'info command' do
      it 'fails if request invalid' do
        response = epp_request('contacts/delete_missing_attr.xml')

        expect(response[:results][0][:result_code]).to eq('2003')
        expect(response[:results][0][:msg]).to eq('Required parameter missing: id')
        expect(response[:results].count).to eq 1
      end

      it 'returns error when object does not exist' do
        response = epp_request('contacts/info.xml')
        expect(response[:result_code]).to eq('2303')
        expect(response[:msg]).to eq('Object does not exist')
        expect(response[:results][0][:value]).to eq('info-4444')
      end

      it 'returns info about contact' do
        Fabricate(:contact, created_by_id: '1', code: 'info-4444', auth_info: '2fooBAR',
                 international_address: Fabricate(:international_address, name: 'Johnny Awesome'))

        response = epp_request('contacts/info.xml')
        contact = response[:parsed].css('resData chkData')

        expect(response[:result_code]).to eq('1000')
        expect(response[:msg]).to eq('Command completed successfully')
        expect(contact.css('name').first.text).to eq('Johnny Awesome')

      end

      it 'doesn\'t disclose private elements' do
        Fabricate(:contact, code: 'info-4444', auth_info: '2fooBAR',
                  disclosure: Fabricate(:contact_disclosure, email: false, phone: false))
        response = epp_request('contacts/info.xml')
        contact = response[:parsed].css('resData chkData')

        expect(response[:result_code]).to eq('1000')

        expect(contact.css('phone').present?).to eq(false)
        expect(contact.css('email').present?).to eq(false)
        expect(contact.css('name').present?).to be(true)
      end

      it 'doesn\'t display unassociated object' do
        Fabricate(:contact, code: 'info-4444')

        response = epp_request('contacts/info.xml')
        expect(response[:result_code]).to eq('2201')
        expect(response[:msg]).to eq('Authorization error')
      end
    end

    context 'renew command' do
      it 'returns 2101-unimplemented command' do
        response = epp_request('contacts/renew.xml')

        expect(response[:result_code]).to eq('2101')
        expect(response[:msg]).to eq('Unimplemented command')
      end
    end
  end
end
