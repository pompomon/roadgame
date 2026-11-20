---
applyTo: "ui/**"
---

# Screens

The § and IDs below are those of docs/ENDGAME.md. EG's Book of Legends (#106) drew 12 findings that this list covers, over 8 Copilot reviews in 4½ hours, and its Atlas (#112) one more. Build each new screen, or new part of one, to it, with a test for each point.

- **Names.** A screen reader doesn't name a control by the labels inside it. A control whose words are in child labels gets an `accessibility_name`, with its state, as `BookCell` and the Atlas's postcards have ("…, stamped"), and so does any control whose own text doesn't name it.
- **Focus.** A `Label` takes no focus. What a screen reader must reach but no tap or key may open, such as a silhouette, a row or a page's lines, takes `FOCUS_ACCESSIBILITY`: only a screen reader's focus stops there, so without one Tab is unchanged (§5.10). Closing a page leaves what opened it in view. 9f8322b followed Tab in a desktop run under Xvfb with `--accessibility always`.
- **Scrolls.** A `ScrollContainer` whose content takes the focus has `follow_focus = true`, or a screen reader's focus can leave the view, as on #112's Atlas until its internal review (`test_the_atlas_scrolls_to_the_postcard_that_has_the_focus`). Godot 4.7.2's scrolls take no key: where the focus has nowhere to go, `MenuScreen.scroll_by_key()` scrolls (W28, W33).
- **Touch.** A control in a scroll doesn't stop the mouse, or a drag that starts on it never scrolls. A button, which stops it by default, passes it on (`mouse_filter = 1`, PASS), even while disabled, as `BookCell` does, and so does a control with a tooltip; a control that needs no mouse at all ignores it (2, IGNORE), as the Atlas's postcards do. The scroll starts as soon as a finger moves, which cancels a button's press, so it needs a deadzone from `Tuning`, as `BOOK_SCROLL_DEADZONE` is. Test a drag and a tap that wobbles with `tests/helpers/finger.gd`.
- **Contrast.** A shape that tells something, such as a silhouette, a seal or a stamp, has 3:1 with its ground (WCAG 2.2 1.4.11), and its states differ in shape, not only in colour: an unearned seal is hollow (W26). Tests compute the ratio, as `test_book_screen.gd`'s `_contrast()` does.
- **Legends' figures.** Test a new view of a figure, such as a still, a silhouette or an icon, on every legend of every pool. The Will-o'-the-Wisp's and the Marfa Lights' figures add light, so they clip over a light ground unless `LegendStill.strength()` bounds them (#104, #106), and their alpha falls to nothing at the edge, so a silhouette draws each texel that the figure covers at all whole (`ui/silhouette.gdshader`, W26).
- **Text.** Lay out with the longest text a control can get: a two-line name over "Not seen yet" covered its still (2866e43). An export breaks a label's lines only at spaces, so break a word too wide as `BookCell.break_hyphens()` does (W25). The font has only its own glyphs (AGENTS.md §2).
