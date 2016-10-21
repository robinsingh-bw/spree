module Spree
  class TaxRate < Spree::Base
    acts_as_paranoid

    include Spree::CalculatedAdjustments
    include Spree::AdjustmentSource

    with_options inverse_of: :tax_rates do
      belongs_to :zone, class_name: "Spree::Zone"
      belongs_to :tax_category,
                 class_name: "Spree::TaxCategory"
    end

    with_options presence: true do
      validates :amount, numericality: { allow_nil: true }
      validates :tax_category
    end

    scope :by_zone, -> (zone) { where(zone_id: zone.id) }
    scope :potential_rates_for_zone,
          -> (zone) do
            where(zone_id: Spree::Zone.potential_matching_zones(zone).pluck(:id))
          end
    scope :for_default_zone,
          -> { potential_rates_for_zone(Spree::Zone.default_tax) }
    scope :for_tax_category,
          -> (category) { where(tax_category_id: category.try(:id)) }
    scope :included_in_price, -> { where(included_in_price: true) }

    # Gets the array of TaxRates appropriate for the specified tax zone
    def self.match(order_tax_zone)
      return [] unless order_tax_zone
      potential_rates_for_zone(order_tax_zone)
    end

    # Pre-tax amounts must be stored so that we can calculate
    # correct rate amounts in the future. For example:
    # https://github.com/spree/spree/issues/4318#issuecomment-34723428
    def self.store_pre_tax_amount(item, rates=nil)
      update_pre_tax_multiplier(item, rates) if !rates.nil?
      update_pre_tax_amount(item)
    end

    def self.update_pre_tax_multiplier(item, rates)
      pre_tax_multiplier = 0
      included_rates = rates.select(&:included_in_price)
      if included_rates.any?
        pre_tax_multiplier = included_rates.map(&:amount).sum
      end
      item.update_column(:pre_tax_multiplier, pre_tax_multiplier)
    end

    def self.update_pre_tax_amount(item)
      pre_tax_amount = case item
                       when Spree::LineItem then item.discounted_amount
                       when Spree::Shipment then item.discounted_cost
                       end
      pre_tax_amount /= (1 + item.pre_tax_multiplier)
      if pre_tax_amount != item.pre_tax_amount
        item.update_column(:pre_tax_amount, pre_tax_amount)
      end
    end

    # Deletes all tax adjustments, then applies all applicable rates
    # to relevant items.
    def self.adjust(order, items)
      rates = match(order.tax_zone)
      tax_categories = rates.map(&:tax_category)

      # using destroy_all to ensure adjustment destroy callback fires.
      Spree::Adjustment.where(adjustable: items).tax.destroy_all

      items.each do |item|
        relevant_rates = rates.select do |rate|
          rate.tax_category == item.tax_category
        end
        store_pre_tax_amount(item, relevant_rates)
        relevant_rates.each do |rate|
          rate.adjust(order, item)
        end
      end
    end

    def self.included_tax_amount_for(options)
      return 0 unless options[:tax_zone] && options[:tax_category]
      potential_rates_for_zone(options[:tax_zone]).
        included_in_price.
        for_tax_category(options[:tax_category]).
        pluck(:amount).sum
    end

    def adjust(order, item)
      create_adjustment(order, item, included_in_price)
    end

    def compute_amount(item)
      # update pre tax amount as it could have changed due to promotions being added/removed
      self.class.update_pre_tax_amount(item)
      compute(item)
    end

    private

    def label
      Spree.t included_in_price? ? :including_tax : :excluding_tax,
              scope: "adjustment_labels.tax_rates",
              name: name.presence || tax_category.name,
              amount: amount_for_label
    end

    def amount_for_label
      return "" unless show_rate_in_label?
      " " + ActiveSupport::NumberHelper::NumberToPercentageConverter.convert(
        amount * 100,
        locale: I18n.locale
      )
    end
  end
end
