Fabricator(:registrant) do
  registrar { Registrar.find_by_code('FIXED') }
  code { sequence(:code) { |i| "REGISTRANT#{Faker::Number.number(8)}#{i}" } }
  auth_info 'password'
  name { sequence(:name) { |i| "REGISTRANT #{Faker::Name.name}#{i}" } }
  phone '+372.12345678'
  email Faker::Internet.email
  street 'Short street 11'
  city 'Tallinn'
  zip '11111'
  country_code 'EE'
  ident '37605030299'
  ident_type 'priv'
  ident_country_code 'EE'
  # rubocop: disable Style/SymbolProc
  after_validation { |c| c.disable_generate_auth_info! }
  # rubocop: enamble Style/SymbolProc
end
