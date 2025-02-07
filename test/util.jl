extract_test_result_value(test_result::Test.Pass) = test_result.value

recursively_unwrap_ex(ex::ErrorException) = ex
recursively_unwrap_ex(ex::Base.IOError) = ex

@static if Base.VERSION >= v"1.2-"
  function recursively_unwrap_ex(outer_ex::TaskFailedException)
    new_thing = outer_ex.task.exception
    return recursively_unwrap_ex(new_thing)
  end
end
  
Base.@kwdef struct ConfigForTestingTaskFailedException
  expected_outer_ex_T
  expected_inner_ex_INSTANCE
end

function test_task_failed_exception(test_result::Test.Pass, cfg::ConfigForTestingTaskFailedException)
  observed_outer_ex = extract_test_result_value(test_result)
  @test observed_outer_ex isa cfg.expected_outer_ex_T

  observed_inner_ex = recursively_unwrap_ex(observed_outer_ex)
  @test observed_inner_ex isa typeof(cfg.expected_inner_ex_INSTANCE)
  @test observed_inner_ex == cfg.expected_inner_ex_INSTANCE

  return nothing
end
