# GdUnit generated TestSuite
class_name h_flow_containerTest
extends GdUnitTestSuite

# TestSuite generated from
const __source = 'res://h_flow_container/h_flow_container.gd'


var _container: HFlowContainer


func before():
	_container = auto_free(HFlowContainer.new())


func test_initial_values() -> void:
	assert_int(_container.size_flags_horizontal).is_equal(Control.SIZE_EXPAND_FILL)
