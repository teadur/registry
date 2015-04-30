class Invoice < ActiveRecord::Base
  include Versions
  belongs_to :seller, class_name: 'Registrar'
  belongs_to :buyer, class_name: 'Registrar'
  has_many :invoice_items
  has_one :account_activity

  accepts_nested_attributes_for :invoice_items

  scope :unbinded, -> { where('id NOT IN (SELECT invoice_id FROM account_activities)') }

  attr_accessor :billing_email
  validates :billing_email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }, allow_blank: true

  validates :invoice_type, :due_date, :currency, :seller_name,
            :seller_iban, :buyer_name, :invoice_items, :vat_prc, presence: true

  before_save :set_invoice_number
  def set_invoice_number
    last_no = Invoice.order(number: :desc).where('number IS NOT NULL').limit(1).pluck(:number).first

    if last_no
      self.number = last_no + 1
    else
      self.number = Setting.invoice_number_min.to_i
    end

    return if number <= Setting.invoice_number_max.to_i

    errors.add(:base, I18n.t('failed_to_generate_invoice'))
    logger.error('INVOICE NUMBER LIMIT REACHED, COULD NOT GENERATE INVOICE')
    false
  end

  before_save -> { self.sum_cache = sum }

  class << self
    def cancel_overdue_invoices
      logger.info "#{Time.zone.now.utc} - Cancelling overdue invoices\n"

      cr_at = Time.zone.now - Setting.days_to_keep_overdue_invoices_active.days
      invoices = Invoice.unbinded.where(
        'due_date < ? AND created_at < ? AND cancelled_at IS NULL', Time.zone.now, cr_at
      )

      count = invoices.update_all(cancelled_at: Time.zone.now)

      logger.info "#{Time.zone.now.utc} - Successfully cancelled #{count} overdue invoices\n"
    end
  end

  def binded?
    account_activity.present?
  end

  def receipt_date
    account_activity.try(:created_at)
  end

  def to_s
    I18n.t('invoice_no', no: number)
  end

  def seller_address
    [seller_street, seller_city, seller_state, seller_zip].reject(&:blank?).compact.join(', ')
  end

  def buyer_address
    [buyer_street, buyer_city, buyer_state, buyer_zip].reject(&:blank?).compact.join(', ')
  end

  def seller_country
    Country.new(seller_country_code)
  end

  def buyer_country
    Country.new(buyer_country_code)
  end

  def pdf(html)
    kit = PDFKit.new(html)
    kit.to_pdf
  end

  def pdf_name
    "invoice-#{number}.pdf"
  end

  def cancel
    if binded?
      errors.add(:base, I18n.t('cannot_cancel_paid_invoice'))
      return false
    end

    if cancelled?
      errors.add(:base, I18n.t('cannot_cancel_cancelled_invoice'))
      return false
    end

    self.cancelled_at = Time.zone.now
    save
  end

  def cancelled?
    cancelled_at.present?
  end

  def forward(html)
    return false unless valid?
    return false unless billing_email.present?

    InvoiceMailer.invoice_email(self, pdf(html)).deliver_now
    true
  end

  def items
    invoice_items
  end

  def sum_without_vat
    items.map(&:item_sum_without_vat).sum
  end

  def vat
    sum_without_vat * vat_prc
  end

  def sum
    sum_without_vat + vat
  end
end
