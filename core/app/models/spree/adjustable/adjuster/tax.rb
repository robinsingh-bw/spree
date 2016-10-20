module Spree
  module Adjustable
    module Adjuster
      class Tax < Spree::Adjustable::Adjuster::Base
        def update
          tax = adjustable.is_a?(Spree::LineItem) ? adjustable.tax_adjustments : adjustments.tax

          included_tax_total = tax.select{|a| a.included == true }.map{ |a|
            is_same = a.adjustable_type == adjustable.class.name &&
                      a.adjustable_id == adjustable.id
            a.update!(is_same ? adjustable : a.adjustable)
          }.compact.sum

          additional_tax_total = tax.select{|a| a.included == false }.map{ |a|
            is_same = a.adjustable_type == adjustable.class.name &&
                      a.adjustable_id == adjustable.id
            a.update!(is_same ? adjustable : a.adjustable)
          }.compact.sum

          update_totals(included_tax_total, additional_tax_total)

          # reset the association cache so it is reloaded the next time
          tax.reset
        end

        private

        def adjustments
          adjustable.try(:all_adjustments) || adjustable.adjustments
        end

        def update_totals(included_tax_total, additional_tax_total)
          @totals[:included_tax_total] = included_tax_total
          @totals[:additional_tax_total] = additional_tax_total
        end
      end
    end
  end
end
