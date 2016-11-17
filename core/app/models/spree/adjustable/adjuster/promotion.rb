module Spree
  module Adjustable
    module Adjuster
      class Promotion < Spree::Adjustable::Adjuster::Base
        def update
          if adjustable.is_a? Spree::LineItem
            promo_adjustments = adjustable.promo_adjustments
          else
            promo_adjustments = adjustments.competing_promos
          end

          promos_total = promo_adjustments.map { |a|
            a.update!(adjustable)
          }.compact.sum

          # if promo_adjustments.size > 0
          #   choose_best_promo_adjustment if promo_adjustments.size > 1
          #   promo_total = best_promo_adjustment.try(:amount).to_f if best_promo_adjustment.try(:promotion?)
          # end
          if promo_adjustments.size > 1
        		choose_best_promo_adjustment
        		best_promo = best_promo_adjustment
      	  else
      		  best_promo = promo_adjustments.first
      	  end

      	  promo_total = best_promo.try(:amount).to_f if best_promo.try(:promotion?)
          update_totals(promo_total)

          # reset the association cache so it is reloaded the next time
          promo_adjustments.reset
        end

        private

        # Picks one (and only one) competing discount to be eligible for
        # this order. This adjustment provides the most discount, and if
        # two adjustments have the same amount, then it will pick the
        # latest one.
        def choose_best_promo_adjustment
          if best_promo_adjustment
            other_promotions = adjustments.competing_promos.where.not(id: best_promo_adjustment.id)
            other_promotions.update_all(eligible: false)
          end
        end

        def best_promo_adjustment
          @best_promo_adjustment ||= begin
            adjustments.competing_promos.eligible.reorder("amount ASC, created_at DESC, id DESC").first
          end
        end

        def update_totals(promo_total)
          promo_total ||= 0.0
          @totals[:promo_total] = promo_total
          @totals[:taxable_adjustment_total] += promo_total
        end
      end
    end
  end
end
