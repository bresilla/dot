#include "{{snake_name}}/{{snake_name}}.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    assert(strcmp({{snake_name}}_greeting(), "hello from {{kebab_name}}") == 0);
    printf("ok\n");
    return 0;
}
