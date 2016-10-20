module Spree
  module Adjustable
    class AdjustmentsUpdater
      def self.update(adjustable)
        new(adjustable).update
      end

      def initialize(adjustable)
        @adjustable = adjustable
        adjustable.reload if shipment? && adjustable.persisted?
      end

      def update
        return unless @adjustable.persisted?

        totals = {
          non_taxable_adjustment_total: 0,
          taxable_adjustment_total: 0
        }
        adjusters.each do |klass|
          klass.adjust(@adjustable, totals)
        end

        persist_totals totals
      end

      private

      def persist_totals(totals)
        totals[:adjustment_total] = totals[:non_taxable_adjustment_total] +
                                    totals[:taxable_adjustment_total] +
                                    totals[:additional_tax_total]

        if @adjustable.attributes.symbolize_keys.slice(*totals.keys) != totals
          totals[:updated_at] = Time.current
          @adjustable.update_columns(totals)
        end
      end

      def shipment?
        @adjustable.is_a?(Shipment)
      end

      def adjusters
        Rails.application.config.spree.adjusters
      end
    end
  end
end
