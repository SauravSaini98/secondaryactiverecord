# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/categorization"
require "models/post"

module SecondaryActiveRecord
  class OrTest < SecondaryActiveRecord::TestCase
    fixtures :posts
    fixtures :authors, :author_addresses

    def test_or_with_relation
      expected = Post.where("id = 1 or id = 2").to_a
      assert_equal expected, Post.where("id = 1").or(Post.where("id = 2")).to_a
    end

    def test_or_identity
      expected = Post.where("id = 1").to_a
      assert_equal expected, Post.where("id = 1").or(Post.where("id = 1")).to_a
    end

    def test_or_with_null_left
      expected = Post.where("id = 1").to_a
      assert_equal expected, Post.none.or(Post.where("id = 1")).to_a
    end

    def test_or_with_null_right
      expected = Post.where("id = 1").to_a
      assert_equal expected, Post.where("id = 1").or(Post.none).to_a
    end

    def test_or_with_bind_params
      assert_equal Post.find([1, 2]).sort_by(&:id), Post.where(id: 1).or(Post.where(id: 2)).sort_by(&:id)
    end

    def test_or_with_null_both
      expected = Post.none.to_a
      assert_equal expected, Post.none.or(Post.none).to_a
    end

    def test_or_without_left_where
      expected = Post.all
      assert_equal expected, Post.or(Post.where("id = 1")).to_a
    end

    def test_or_without_right_where
      expected = Post.all
      assert_equal expected, Post.where("id = 1").or(Post.all).to_a
    end

    def test_or_preserves_other_querying_methods
      expected = Post.where("id = 1 or id = 2 or id = 3").order("body asc").to_a
      partial = Post.order("body asc")
      assert_equal expected, partial.where("id = 1").or(partial.where(id: [2, 3])).to_a
      assert_equal expected, Post.order("body asc").where("id = 1").or(Post.order("body asc").where(id: [2, 3])).to_a
    end

    def test_or_with_incompatible_relations
      error = assert_raises ArgumentError do
        Post.order("body asc").where("id = 1").or(Post.order("id desc").where(id: [2, 3])).to_a
      end

      assert_equal "Relation passed to #or must be structurally compatible. Incompatible values: [:order]", error.message
    end

    def test_or_with_unscope_where
      expected = Post.where("id = 1 or id = 2")
      partial = Post.where("id = 1 and id != 2")
      assert_equal expected, partial.or(partial.unscope(:where).where("id = 2")).to_a
    end

    def test_or_with_unscope_where_column
      expected = Post.where("id = 1 or id = 2")
      partial = Post.where(id: 1).where.not(id: 2)
      assert_equal expected, partial.or(partial.unscope(where: :id).where("id = 2")).to_a
    end

    def test_or_with_unscope_order
      expected = Post.where("id = 1 or id = 2")
      assert_equal expected, Post.order("body asc").where("id = 1").unscope(:order).or(Post.where("id = 2")).to_a
    end

    def test_or_with_incompatible_unscope
      error = assert_raises ArgumentError do
        Post.order("body asc").where("id = 1").or(Post.order("body asc").where("id = 2").unscope(:order)).to_a
      end

      assert_equal "Relation passed to #or must be structurally compatible. Incompatible values: [:order]", error.message
    end

    def test_or_when_grouping
      groups = Post.where("id < 10").group("body").select("body, COUNT(*) AS c")
      expected = groups.having("COUNT(*) > 1 OR body like 'Such%'").to_a.map { |o| [o.body, o.c] }
      assert_equal expected, groups.having("COUNT(*) > 1").or(groups.having("body like 'Such%'")).to_a.map { |o| [o.body, o.c] }
    end

    def test_or_with_named_scope
      expected = Post.where("id = 1 or body LIKE '\%a\%'").to_a
      assert_equal expected, Post.where("id = 1").or(Post.containing_the_letter_a)
    end

    def test_or_inside_named_scope
      expected = Post.where("body LIKE '\%a\%' OR title LIKE ?", "%'%").order("id DESC").to_a
      assert_equal expected, Post.order(id: :desc).typographically_interesting
    end

    def test_or_on_loaded_relation
      expected = Post.where("id = 1 or id = 2").to_a
      p = Post.where("id = 1")
      p.load
      assert_equal true, p.loaded?
      assert_equal expected, p.or(Post.where("id = 2")).to_a
    end

    def test_or_with_non_relation_object_raises_error
      assert_raises ArgumentError do
        Post.where(id: [1, 2, 3]).or(title: "Rails")
      end
    end

    def test_or_with_references_inequality
      joined = Post.includes(:author)
      actual = joined.where(authors: { id: 1 })
        .or(joined.where(title: "I don't have any comments"))
      expected = Author.find(1).posts + Post.where(title: "I don't have any comments")
      assert_equal expected.sort_by(&:id), actual.sort_by(&:id)
    end

    def test_or_with_scope_on_association
      author = Author.first
      assert_nothing_raised do
        author.top_posts.or(author.other_top_posts)
      end
    end
  end
end
