# frozen_string_literal: true

require "cases/helper"
require "models/lesson"
require "models/student"

class HabtmDestroyOrderTest < SecondaryActiveRecord::TestCase
  test "may not delete a lesson with students" do
    sicp = Lesson.new(name: "SICP")
    ben = Student.new(name: "Ben Bitdiddle")
    sicp.students << ben
    sicp.save!
    assert_raises LessonError do
      assert_no_difference("Lesson.count") do
        sicp.destroy
      end
    end
    assert_not_predicate sicp, :destroyed?
  end

  test "should not raise error if have foreign key in the join table" do
    student = Student.new(name: "Ben Bitdiddle")
    lesson = Lesson.new(name: "SICP")
    lesson.students << student
    lesson.save!
    assert_nothing_raised do
      student.destroy
    end
  end

  test "not destroying a student with lessons leaves student<=>lesson association intact" do
    # test a normal before_destroy doesn't destroy the habtm joins
    begin
      sicp = Lesson.new(name: "SICP")
      ben = Student.new(name: "Ben Bitdiddle")
      # add a before destroy to student
      Student.class_eval do
        before_destroy do
          raise SecondaryActiveRecord::Rollback unless lessons.empty?
        end
      end
      ben.lessons << sicp
      ben.save!
      ben.destroy
      assert_not_empty ben.reload.lessons
    ensure
      # get rid of it so Student is still like it was
      Student.reset_callbacks(:destroy)
    end
  end

  test "not destroying a lesson with students leaves student<=>lesson association intact" do
    # test a more aggressive before_destroy  doesn't destroy the habtm joins and still throws the exception
    sicp = Lesson.new(name: "SICP")
    ben = Student.new(name: "Ben Bitdiddle")
    sicp.students << ben
    sicp.save!
    assert_raises LessonError do
      sicp.destroy
    end
    assert_not_empty sicp.reload.students
  end
end
