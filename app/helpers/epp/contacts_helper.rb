module Epp::ContactsHelper
  def create_contact
    ph = get_params_hash('epp command create create')[:create]

    @contact = Contact.new(
      code: ph[:id],
      name: ph[:postalInfo][:name],
      phone: ph[:voice],
      email: ph[:email],
      reg_no: ph[:ident]
    )

    @contact.addresses << Address.new(
      country_id: Country.find_by(iso: ph[:postalInfo][:cc]),
      street: ph[:postalInfo][:street],
      zip: ph[:postalInfo][:pc]
    )

    @contact.save
    render '/epp/contacts/create'
  end
end