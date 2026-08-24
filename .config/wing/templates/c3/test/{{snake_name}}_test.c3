module {{snake_name}}_test;
import {{snake_name}};

fn void test_greeting() @test
{
	assert({{snake_name}}::greeting() == "hello from {{kebab_name}}");
}
