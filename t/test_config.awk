# deps: assert.awk awkbot_awkbot_config.awk

BEGIN {
#    awkbot_config["debug"] = 1
    config_load("t/test_config.conf")

    for (key in _config) {
        print gensub(SUBSEP, ".", "g", key) ":", awkbot_config[key]
    }

    assert((config("Test")    == 1), "Test failed")
    assert((config("foo.bar") == 2), "Test failed")
    assert((config("foo.baz") == 3), "Test failed")

    print "OKAY, Passed tests"
    print "This is 3:", config("foo.baz")
    exit (0)
}
