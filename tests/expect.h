#define expect(expr) ((void)((expr) || (on_expect_fail(#expr, __FILE__, __LINE__, __func__),0)))

// TODO: mark on_expect_fail as noreturn
void on_expect_fail(const char *expression, const char *file, int line, const char *func);
