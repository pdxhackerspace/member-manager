require 'test_helper'

class AccessControllerTextNormalizerTest < ActiveSupport::TestCase
  test 'returns nil for nil input' do
    assert_nil AccessControllerTextNormalizer.call(nil)
  end

  test 'passes through plain ASCII text' do
    assert_equal 'exampleuser', AccessControllerTextNormalizer.call('exampleuser')
    assert_equal 'Laser Cutting', AccessControllerTextNormalizer.call('Laser Cutting')
  end

  test 'transliterates accented characters to ASCII' do
    assert_equal 'Jose', AccessControllerTextNormalizer.call('José')
    assert_equal 'Muller', AccessControllerTextNormalizer.call('Müller')
  end

  test 'drops characters that cannot be represented in ASCII' do
    assert_equal '', AccessControllerTextNormalizer.call('用户')
    assert_equal 'hello', AccessControllerTextNormalizer.call('hello用户')
    assert_equal 'cafe', AccessControllerTextNormalizer.call('café ☕')
  end
end
