require 'test_helper'

class TrainingTopicHierarchyTest < ActiveSupport::TestCase
  setup do
    @parent = training_topics(:laser_cutting)
    @child = TrainingTopic.create!(name: 'Hierarchy child', parent: @parent)
  end

  test 'a topic knows whether it is a root or a subtopic' do
    assert_predicate @parent, :root?
    assert_not @parent.subtopic?
    assert_predicate @child, :subtopic?
    assert_not @child.root?
  end

  test 'children are listed under their parent' do
    assert_includes @parent.children, @child
    assert_equal @parent, @child.parent
  end

  test 'a topic cannot be its own parent' do
    @parent.parent_id = @parent.id

    assert_not @parent.valid?
    assert_includes @parent.errors[:parent_id], 'cannot be the topic itself'
  end

  test 'a topic cannot be parented to its own subtopic' do
    @parent.parent = @child

    assert_not @parent.valid?
    assert_includes @parent.errors[:parent_id], "cannot be one of this topic's own subtopics"
  end

  test 'a topic cannot be parented to a deeper descendant' do
    grandchild = TrainingTopic.create!(name: 'Hierarchy grandchild', parent: @child)
    @parent.parent = grandchild

    assert_not @parent.valid?
  end

  test 'descendant_ids collects the whole subtree' do
    grandchild = TrainingTopic.create!(name: 'Hierarchy grandchild', parent: @child)

    assert_equal [@child.id, grandchild.id].sort, @parent.descendant_ids.sort
  end

  test 'eligible_parents excludes the topic itself and its descendants' do
    grandchild = TrainingTopic.create!(name: 'Hierarchy grandchild', parent: @child)
    eligible = @parent.eligible_parents

    assert_not_includes eligible, @parent
    assert_not_includes eligible, @child
    assert_not_includes eligible, grandchild
    assert_includes eligible, training_topics(:woodworking)
  end

  test 'deleting a parent promotes its subtopics to top level' do
    doomed = TrainingTopic.create!(name: 'Doomed parent')
    orphan = TrainingTopic.create!(name: 'Surviving subtopic', parent: doomed)

    doomed.destroy

    assert_nil orphan.reload.parent_id
  end

  test 'tree_ordered lists each parent immediately before its subtopics' do
    ordered = TrainingTopic.tree_ordered
    names = ordered.map { |topic, _depth| topic.name }
    depths = ordered.to_h { |topic, depth| [topic.name, depth] }

    assert_equal names.index(@parent.name) + 1, names.index(@child.name)
    assert_equal 0, depths[@parent.name]
    assert_equal 1, depths[@child.name]
  end

  test 'tree_ordered returns every topic exactly once' do
    ordered = TrainingTopic.tree_ordered

    assert_equal TrainingTopic.count, ordered.size
    assert_equal ordered.map { |topic, _depth| topic.id }.uniq.size, ordered.size
  end
end
