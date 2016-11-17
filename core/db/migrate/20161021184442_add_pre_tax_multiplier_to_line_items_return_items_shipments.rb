class AddPreTaxMultiplierToLineItemsReturnItemsShipments < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :pre_tax_multiplier, :decimal, precision: 8, scale: 5, default: 0, null: false
    add_column :spree_return_items, :pre_tax_multiplier, :decimal, precision: 8, scale: 5, default: 0, null: false
    add_column :spree_shipments, :pre_tax_multiplier, :decimal, precision: 8, scale: 5, default: 0, null: false
  end
end
