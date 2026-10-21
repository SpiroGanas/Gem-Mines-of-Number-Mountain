from render_policy import render


def test_renders_headings_lists_bold_and_links() -> None:
    page = render("# Title\n\nHello **you** [x](http://a.b)\n\n- one\n- two\n")
    assert "<h1>Title</h1>" in page and "<strong>you</strong>" in page
    assert '<a href="http://a.b">x</a>' in page and page.count("<li>") == 2 and "</ul>" in page


def test_escapes_html() -> None:
    assert "&lt;script&gt;" in render("<script>")
