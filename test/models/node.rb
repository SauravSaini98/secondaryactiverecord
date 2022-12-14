# frozen_string_literal: true

class Node < SecondaryActiveRecord::Base
  belongs_to :tree, touch: true
  belongs_to :parent,   class_name: "Node", touch: true, optional: true
  has_many   :children, class_name: "Node", foreign_key: :parent_id, dependent: :destroy
end
