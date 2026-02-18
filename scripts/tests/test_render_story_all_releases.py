from __future__ import annotations

import importlib.util
import pathlib
import re
import sys
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
RENDER_STORY_PATH = REPO_ROOT / "scripts" / "render_story.py"


def load_render_story_module():
    spec = importlib.util.spec_from_file_location("render_story", RENDER_STORY_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load scripts/render_story.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


render_story = load_render_story_module()


class AllReleasesViewTests(unittest.TestCase):
    def test_parse_release_date_supports_year_month_day(self):
        self.assertEqual(
            str(render_story.parse_release_date("1999")),
            "1999-01-01",
        )
        self.assertEqual(
            str(render_story.parse_release_date("1999-06")),
            "1999-06-01",
        )
        self.assertEqual(
            str(render_story.parse_release_date("1999-06-15")),
            "1999-06-15",
        )
        self.assertIsNone(render_story.parse_release_date("invalid"))

    def test_render_all_releases_orders_and_filters_types(self):
        media_lookup = {
            "alb-1999": render_story.StoryMedia(
                key="alb-1999",
                type="album",
                apple_music_id="1",
                title="1999",
                artist="Prince",
                artwork_url=None,
                apple_music_url=None,
                release_date="1982-10-27",
            ),
            "trk-doves": render_story.StoryMedia(
                key="trk-doves",
                type="track",
                apple_music_id="2",
                title="When Doves Cry",
                artist="Prince",
                artwork_url=None,
                apple_music_url=None,
                release_date="1984-05",
            ),
            "vid-rain": render_story.StoryMedia(
                key="vid-rain",
                type="music-video",
                apple_music_id="3",
                title="Purple Rain",
                artist="Prince",
                artwork_url=None,
                apple_music_url=None,
                release_date="1984-11-10",
            ),
            "pl-mix": render_story.StoryMedia(
                key="pl-mix",
                type="playlist",
                apple_music_id="4",
                title="Prince Essentials",
                artist="Apple Music",
                artwork_url=None,
                apple_music_url=None,
                release_date="1990-01-01",
            ),
            "alb-undated": render_story.StoryMedia(
                key="alb-undated",
                type="album",
                apple_music_id="5",
                title="Undated Album",
                artist="Prince",
                artwork_url=None,
                apple_music_url=None,
                release_date=None,
            ),
        }

        html = render_story.render_all_releases_view(media_lookup, asset_prefix=None)

        self.assertIn('data-release-filter="all"', html)
        self.assertIn('data-release-filter="album"', html)
        self.assertIn('data-release-filter="track"', html)
        self.assertIn('data-release-filter="music-video"', html)
        self.assertIn('data-release-filter="playlist"', html)
        self.assertIn('data-media-key="pl-mix"', html)

        order = re.findall(r'data-media-key="([^"]+)"', html)
        self.assertEqual(
            order,
            ["alb-1999", "trk-doves", "vid-rain", "pl-mix", "alb-undated"],
        )

    def test_render_story_html_includes_all_releases_section(self):
        story = render_story.Story(
            meta={
                "title": "Test Story",
                "authors": ["Tester"],
                "publish_date": "2026-02-15",
            },
            sections=[
                render_story.StorySection(
                    id="s1",
                    title="Section 1",
                    layout=None,
                    body="A paragraph.",
                )
            ],
            media={
                "a": render_story.StoryMedia(
                    key="a",
                    type="album",
                    apple_music_id="10",
                    title="Album A",
                    artist="Artist A",
                    artwork_url=None,
                    apple_music_url=None,
                    release_date="2001",
                ),
                "b": render_story.StoryMedia(
                    key="b",
                    type="track",
                    apple_music_id="11",
                    title="Track B",
                    artist="Artist B",
                    artwork_url=None,
                    apple_music_url=None,
                    release_date=None,
                ),
            },
        )

        html = render_story.render_story_html(story)

        self.assertIn("All Releases", html)
        self.assertIn("Release date unknown", html)
        self.assertIn("media-badge-album", html)
        self.assertIn("media-badge-track", html)
        self.assertLess(html.find('class="all-releases"'), html.find('class="section"'))


if __name__ == "__main__":
    unittest.main()
