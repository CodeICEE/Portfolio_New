# Upgrade Notes — Rails 6.1 / Ruby 2.7 → Rails 8.1 / Ruby 3.4

Branch: `upgrade/rails-8`

This document explains every change on this branch: what changed, *why*, and
the concept behind it. Read it top to bottom once, then use it as a reference.

**Before anything works, you must run `bundle install`.** I could not run it —
the machine I worked on has no network access to rubygems.org — so
`Gemfile.lock` was deleted rather than left stale. See
[What I could not verify](#8-what-i-could-not-verify) for the honest list of
what is and is not confirmed working.

---

## 0. The 60-second version

| | Before | After |
|---|---|---|
| Ruby | 2.7.2 (EOL March 2023) | 3.4.10 |
| Rails | 6.1.4 | 8.1.3 |
| Asset pipeline | Sprockets + Webpacker 5 | Propshaft |
| CSS build | `sass-rails` (libsass) | `dartsass-rails` |
| JS build | webpack + Babel + yarn + Node | none — there was no JavaScript to build |
| Bootstrap | `bootstrap` gem, `@import`ed into SCSS | CDN `<link>` |
| Database | none | still none |
| Node dependency | required | gone |

Net effect: **57 files changed, 898 lines deleted, 246 added.** The app got
substantially smaller, which is the point — most of what was removed existed
only to run a JavaScript build for an app with no JavaScript.

---

## 1. Why the upgrade was mandatory, not optional

Heroku installs the Ruby version recorded in `Gemfile.lock`. As of today it
supports exactly three: **3.3.12, 3.4.10, and 4.0.6**. Older versions are
listed as "available at your own risk" only back to 3.1 or 3.2 depending on
stack. Ruby 2.7 is not on either list, so `git push heroku` would have failed
at the build step. There was no version of "just deploy it as-is."

That forces a chain:

```
Ruby 2.7 unsupported
  → need Ruby ≥ 3.3
    → Rails 6.1 doesn't support Ruby 3.3 (it caps out around 3.1)
      → need Rails ≥ 7.1
        → Webpacker was retired in Rails 7 and is unmaintained
          → need a new asset pipeline
```

This is the normal shape of a Rails upgrade: one forced move cascades. It is
also why upgrading yearly is much cheaper than upgrading every four years.

We went to **Rails 8.1** (current, supported until Oct 2027) rather than the
minimum viable 7.1, because the app is tiny — three controllers, no database,
no models — so the extra distance costs almost nothing and you end up learning
the version you'd actually encounter in a job today.

---

## 2. Ruby and Rails

### `Gemfile` — rewritten

Removed and why:

| Gem | Why it's gone |
|---|---|
| `sass-rails` | Wraps libsass, which was **deprecated in 2020**. Replaced by `dartsass-rails`, which wraps Dart Sass, the only implementation Sass upstream still maintains. |
| `webpacker` | Retired in Rails 7. It was building exactly one file (`packs/application.js`) that imported `@rails/ujs` and an empty file. |
| `bootstrap` (gem) | See [section 4](#4-bootstrap-moved-to-a-cdn). |
| `jbuilder` | Builds JSON API responses. This app has no JSON endpoints. |
| `byebug` | Superseded by `debug`, which ships with Ruby 3.1+ and is the Rails default. Use `binding.break` where you used to use `byebug`. |
| `webdrivers` | Unmaintained and unnecessary — Selenium 4.11+ downloads matching browser drivers itself via Selenium Manager. |
| `rack-mini-profiler` | A performance profiler for a static site with no database queries. Nothing to profile. |

Added:

- **`propshaft`** — the Rails 8 asset pipeline. Not bundled with Rails; you
  must declare it.
- **`dartsass-rails`** — compiles your SCSS.
- **`debug`** — the modern debugger.

Also note the platform syntax change:

```ruby
# Rails 6.1 era
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Now
gem "tzinfo-data", platforms: %i[windows jruby]
```

Bundler collapsed the three separate Windows platform names into one
`:windows`. This matters to you specifically — you're developing on Windows,
where Ruby doesn't ship the timezone database.

### `.ruby-version` — `ruby-2.7.2` → `3.4.10`

The `ruby-` prefix was an old rbenv-ism. Modern version managers (and
`.ruby-version` as a standard) want a bare version number.

### `config/application.rb`

```ruby
config.load_defaults 8.1   # was 6.1
```

**This one line is the actual upgrade.** Rails ships every behaviour change
behind a version-gated default. `load_defaults 6.1` meant that even after
installing Rails 8, you'd still get 2021 behaviour for cookie serialization,
CSRF token format, cache format, and dozens of other things. Bumping it opts
into current behaviour all at once.

For a bigger app you'd bump this *last*, after using
`rails app:update` to generate a `new_framework_defaults_8_1.rb` file and
flipping the settings on one at a time. For an app with no database and no
persisted state, flipping them all together is safe.

Two other changes here:

```ruby
# require "action_cable/engine"     ← now commented out
config.autoload_lib(ignore: %w[assets tasks])   ← new
```

**Action Cable was removed deliberately, and it's a Heroku trap worth
understanding.** Your app never used WebSockets — `app/channels/` contained
only the empty generated boilerplate. But `config/cable.yml` declared
`adapter: redis` for production, so booting with Action Cable loaded would
have expected a `REDIS_URL`. And in Rails 8 the *new* default is Solid Cable,
which is backed by a database table — so regenerating that file would have
handed you a Postgres requirement for a feature you don't use. Deleting the
whole subsystem is cleaner than configuring something you'll never call.

`autoload_lib` is a Rails 7.1+ convenience that puts `lib/` on the autoload
path, with an ignore list for subdirectories that don't contain classes.

### `config/environments/*.rb` — regenerated

These files are effectively Rails-version-specific, so they were rewritten in
Rails 8 style rather than patched. Notable renames and additions:

- `config.cache_classes = false` → **`config.enable_reloading = true`**. Same
  behaviour, honest name. (`cache_classes` was always confusing because it was
  really about reloading, not caching.)
- `config.action_dispatch.show_exceptions = false` → **`= :rescuable`**. It's a
  three-way symbol now (`:all` / `:rescuable` / `:none`) instead of a boolean.
- `config.log_formatter` + manual `ActiveSupport::Logger.new(STDOUT)` →
  **`config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)`**.
- New: `config.action_view.annotate_rendered_view_with_filenames = true` in
  development. Rendered HTML gets comments telling you which partial produced
  each chunk. Genuinely useful when re-learning a codebase.

Heroku-specific choices in `production.rb` are covered in
[section 5](#5-heroku-configuration).

---

## 3. The asset pipeline — the biggest conceptual change

This is the part most worth actually understanding, because the Rails asset
story changed shape between 6.1 and 8.

### What you had

Two pipelines running side by side:

- **Sprockets** handled `app/assets/` — it concatenated, ran SCSS through
  libsass, minified, and fingerprinted. Driven by `app/assets/config/manifest.js`
  and `//= require` / `require_tree` directives.
- **Webpacker** handled `app/javascript/` — a Rails wrapper around webpack,
  with `config/webpacker.yml`, `config/webpack/*.js`, `babel.config.js`,
  `postcss.config.js`, `package.json`, `yarn.lock`, and a `node_modules/`.

Webpacker existed to solve "I want to write modern JS with npm packages."
It was heavy, slow, and famously hard to debug.

### What you have now

**Propshaft**, and it does dramatically less on purpose:

> Propshaft finds files, gives them a content-hash filename, and serves them.
> That's it. No concatenation, no transpiling, no minification, no directives.

The Rails team's bet was that HTTP/2 made concatenation unnecessary and that
browsers now natively support ES modules and CSS features that Babel/PostCSS
used to polyfill. So the pipeline's only remaining job is **fingerprinting**:
turning `application.css` into `application-a1b2c3d4.css` so it can be cached
forever and busted automatically when contents change.

Anything that genuinely needs *building* is handled by a separate gem that
writes plain output into `app/assets/builds/`, which Propshaft then picks up.
For you, that's Dart Sass.

The full flow now:

```
app/assets/stylesheets/application.scss     ← you edit this
        │
        │  dartsass-rails  (`rails dartsass:build`)
        ▼
app/assets/builds/application.css           ← generated, gitignored
        │
        │  Propshaft  (`rails assets:precompile`)
        ▼
public/assets/application-<digest>.css      ← served to browsers
```

`dartsass:build` is automatically hooked onto `assets:precompile`, so Heroku
runs both with no extra configuration.

### Files deleted as a result

`app/assets/config/manifest.js`, `config/initializers/assets.rb`,
`config/webpacker.yml`, `config/webpack/*`, `babel.config.js`,
`postcss.config.js`, `package.json`, `yarn.lock`, `.browserslistrc`,
`bin/webpack`, `bin/webpack-dev-server`, `bin/yarn`, `app/javascript/`.

Your app now has **no Node.js dependency at all**. Heroku won't install Node,
which also makes deploys noticeably faster.

### `pages.scss` and `projects.scss` deleted

Both contained nothing but the generator's placeholder comments. Sprockets
auto-included them via `require_tree`; Dart Sass has no equivalent — it
compiles exactly one entry point. If you add a stylesheet now, you pull it in
explicitly:

```scss
// app/assets/stylesheets/application.scss
@use "projects";   // loads _projects.scss
```

(Note `@use`, not `@import` — Sass deprecated `@import` and it is scheduled for
removal.)

### Images moved: `app/assets/stylesheets/imgs/` → `app/assets/images/imgs/`

**This was required, not cosmetic.** Your SCSS contains six references like:

```scss
background-image: linear-gradient(...), url("imgs/main-bg3.jpg");
```

Under Sprockets those resolved because the images sat next to the stylesheet.
Propshaft resolves `url()` differently: it treats a plain relative path as a
**logical path** looked up across the asset load paths, resolved relative to
the *output* file's directory. The output now lives in `app/assets/builds/`,
so `imgs/main-bg3.jpg` had to become a valid logical path in its own right.
Moving the folders under `app/assets/images/` does exactly that — and the SCSS
text itself needed no edits.

Failure mode if this is ever wrong: Propshaft logs
`Unable to resolve 'imgs/x.jpg'` and leaves the URL untouched. You get a
missing background image, not a crash — which makes it easy to miss.
`project-imgs/` moved for the same reason.

### Two stray semicolons fixed

`app/assets/stylesheets/application.scss` had `};` closing two blocks (lines
285 and 583). libsass tolerated it. Dart Sass is a stricter parser and this is
exactly the class of thing that breaks on the switch, so both were removed.

---

## 4. Bootstrap moved to a CDN

I audited every `class="..."` in every view. The complete set of Bootstrap
classes your site uses is:

```
btn        (7 uses)
btn-lg     (4 uses)
```

No grid (`row`/`col`), no `container`, no `navbar`, no cards, and **no
Bootstrap JavaScript components** — no modals, dropdowns, collapses,
carousels or tooltips. Your layout is hand-written flexbox and CSS Grid, and
your mobile menu is a custom burger with inline JS. Your `@import "bootstrap"`
was pulling in ~230KB of Sass to get `.btn`, `.btn-lg`, and Reboot's baseline
resets.

So Bootstrap is now a plain stylesheet link in the layout:

```erb
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css"
      rel="stylesheet" integrity="sha384-sRIl4kxILF..." crossorigin="anonymous">
```

**Why this and not the gem?** The `bootstrap` gem's Sass has to be compiled,
which means wiring Dart Sass load paths to a gem's internals — more config,
and one more thing to break on a future upgrade. Since you use none of
Bootstrap's Sass variables or mixins, compiling it buys you nothing. You were
already loading Mapbox GL and Google Fonts from CDNs, so this is consistent
with the rest of the layout.

The `integrity` attribute is Subresource Integrity: the browser hashes the
downloaded file and refuses to apply it if the hash doesn't match, so a
compromised CDN can't inject CSS into your site.

**Two things to watch:**

1. This is a jump from Bootstrap **5.1.3 → 5.3.8**. 5.3 rewrote `.btn` to use
   CSS custom properties. Your `.btn-custom-1` / `.btn-custom-2` / `.btn-shop`
   classes override background, color and border explicitly, so they should
   look identical — but check the buttons visually when you first boot it. If
   anything looks off, pin the CDN URL to `bootstrap@5.1.3` and the rendering
   will be byte-identical to before.
2. If you later want Bootstrap's Sass back (to theme it with variables rather
   than override it), add `gem "bootstrap"`, drop the CDN link, and put
   `@use "bootstrap";` at the top of `application.scss`.

---

## 5. Heroku configuration

### `Procfile` (new)

```
web: bundle exec puma -C config/puma.rb
```

Without this, Heroku guesses. Being explicit means the command that runs in
production is the one you can read in the repo.

### `config/puma.rb` — rewritten and sized for a small dyno

The old file came from the Rails 6.1 generator and defaulted to 5 threads with
`WEB_CONCURRENCY` workers. On a 512MB Eco/Basic dyno with one shared CPU core,
**workers are the thing that gets you an R14 memory error** — each worker is a
separate OS process holding a near-full copy of your app.

```ruby
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count
port ENV.fetch("PORT", 3000)          # ← Heroku assigns this at boot
workers ENV.fetch("WEB_CONCURRENCY", 0)
preload_app! if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 1
```

The `port ENV.fetch("PORT", 3000)` line matters more than it looks. Heroku
assigns a random port and passes it in `$PORT`; binding to anything else means
the dyno never answers the health check and you get **R10 Boot timeout**,
which is probably the single most common first-deploy failure.

### `production.rb` — the Heroku-specific bits

```ruby
config.public_file_server.enabled = true
```

Was `ENV['RAILS_SERVE_STATIC_FILES'].present?`. There is no NGINX in front of
a Heroku dyno, so Rails must serve its own assets. Making it unconditional
removes a config var you'd otherwise have to remember to set — and forgetting
it produces an unstyled site with no error message, which is a miserable thing
to debug.

```ruby
config.assume_ssl = true
config.force_ssl  = true
```

`force_ssl` alone would infinite-redirect on Heroku. The router terminates TLS
and forwards to your dyno over plain HTTP with an `X-Forwarded-Proto: https`
header; without `assume_ssl`, Rails sees HTTP, redirects to HTTPS, and the
cycle repeats. `assume_ssl` tells Rails to trust that header. **Always set both
together behind a proxy.**

```ruby
config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
```

Was gated behind `ENV["RAILS_LOG_TO_STDOUT"]`. Heroku dynos have an ephemeral
filesystem and the log drain reads stdout, so writing to `log/production.log`
means your logs vanish on every restart. Unconditional is correct here.

### `GET /up` health check route (new)

```ruby
get "up" => "rails/health#show", as: :rails_health_check
```

Rails 7.1+ ships this controller. Returns 200 if the app booted, 500 if it
raised. Useful for uptime monitors — and if you're on an Eco dyno that sleeps,
pinging it is how you'd keep it awake (though that burns your 1,000 monthly
hours, so Basic is the honest solution).

`config.silence_healthcheck_path` keeps those pings out of your logs.

### `bin/rails` and `bin/rake` shebangs — a real latent bug

```diff
- #!/usr/bin/env ruby.exe
+ #!/usr/bin/env ruby
```

Something on your Windows machine wrote `ruby.exe` into these binstubs. There
is no `ruby.exe` on Linux, so these scripts were broken on any non-Windows
machine. Heroku's buildpack calls `bundle exec rake assets:precompile` rather
than `bin/rails`, so it probably wouldn't have bitten you during deploy — but
it would have the moment you tried `heroku run bin/rails console`.

The new `.gitattributes` (`* text=auto eol=lf`) prevents the related class of
problem: your entire working tree was CRLF while the repository stored LF, so
`git status` showed all 98 files as modified. The first commit on this branch
normalizes that.

---

## 6. Other fixes

**`ProjectsController#keyman` → `#mightylocksmith`.** The route was
`get "projects/mightylocksmith"` but the action was named `keyman`. Rails was
falling back to implicit rendering — when no action method exists but a
matching template does, it renders the template anyway — so the page worked by
accident. `keyman` was unreachable dead code. Now they match.

**`test/channels/`** deleted along with Action Cable.

**`.gitignore`** now ignores `/app/assets/builds/*` (generated CSS is build
output, not source) and no longer mentions `node_modules`, `/public/packs`, or
yarn logs.

---

## 7. What you need to do

### Locally

1. **Install Ruby 3.4.10.** On Windows, use
   [RubyInstaller](https://rubyinstaller.org/) and pick the **Ruby+Devkit**
   variant — several gems compile native extensions.
2. ```
   bundle install
   ```
   This regenerates `Gemfile.lock`, including the `RUBY VERSION` and
   `BUNDLED WITH` blocks Heroku reads. **Commit the new lockfile.**
3. ```
   bin/rails dartsass:build
   ```
   Compiles `application.scss` → `app/assets/builds/application.css`. Without
   this the app raises on `stylesheet_link_tag` because the file doesn't exist
   yet.
4. ```
   bin/rails server
   ```
   Then check every page: `/`, `/pages/aboutme`, `/pages/contactme`,
   `/projects/mightylocksmith`, `/projects/portfolio`, `/projects/fafsa`.
   Specifically look at **background images** (the `url()` change) and
   **buttons** (the Bootstrap version bump).

   While actively editing SCSS, run `bin/rails dartsass:watch` in a second
   terminal so changes recompile automatically. On Windows, `bin/dev` needs a
   POSIX shell (Git Bash) — two terminals is the simpler path.

### On Heroku

```bash
heroku create your-app-name
heroku stack:set heroku-24                  # or heroku-26
heroku config:set SECRET_KEY_BASE=$(bundle exec rails secret)
heroku config:set RAILS_ENV=production RACK_ENV=production
git push heroku upgrade/rails-8:main
```

**About `SECRET_KEY_BASE`:** `config/master.key` isn't present in this
directory, so `config/credentials.yml.enc` can't be decrypted. Rails checks
`ENV["SECRET_KEY_BASE"]` before falling back to credentials, so setting the
config var sidesteps it entirely. Nothing in this app stores secrets in
credentials — the Mapbox token is a public token hardcoded in
`app/views/pages/contactme.html.erb` — so you can safely delete
`config/credentials.yml.enc` and start fresh with
`bin/rails credentials:edit` if you ever need it.

**Plan and add-ons**, to restate the earlier answer:

- **Dyno:** Basic ($7/mo) — never sleeps, includes automated certificate
  management for a custom domain. Eco ($5/mo for 1,000 hours pooled across all
  your apps) works but sleeps after 30 minutes idle, giving a ~10s cold start.
- **Add-ons: none.** No database, no Redis, no mail. Confirmed by audit: no
  Active Record, no `config/database.yml`, no `db/`, no models, no forms in any
  view.

---

## 8. What I could not verify

I want to be straight about this rather than let you find out the hard way.
The sandbox I worked in has Ruby 3.0 and no network access to rubygems.org, so
**I could not run `bundle install`, boot the app, or compile the SCSS.**

What I *did* verify, statically:

- `ruby -c` parses all 28 `.rb` files
- All 14 ERB templates compile
- All `config/*.yml` files parse
- All 6 `url()` references in the SCSS resolve to a real file on a Propshaft
  load path (this was the highest-risk change, so I read Propshaft's
  `CssAssetUrls` source to confirm the resolution rule rather than guess)
- All `image_tag` references resolve to files that exist
- No leftover references to `javascript_pack_tag`, `require_tree`, `webpacker`,
  `turbolinks`, or `@rails/ujs`
- Every route maps to a real controller action and a real template

What remains genuinely unproven, ranked by how likely it is to bite:

1. **Gem resolution.** `bundle install` may surface a version conflict I
   couldn't see. Most likely candidate: a `dartsass-rails` / `propshaft`
   constraint against Rails 8.1.
2. **Dart Sass compiling 870 lines of SCSS written for libsass.** I removed the
   two stray semicolons and confirmed there's no `@import`, no `/` division, no
   `#{}` interpolation, no mixins or functions — the file is close to plain CSS
   — but Dart Sass may still warn or error on something I didn't anticipate.
3. **Bootstrap 5.1 → 5.3 visual differences** on `.btn` and `.btn-lg`.
4. **Background images resolving through Propshaft.** Reasoned from source and
   verified the paths exist, but never actually executed.

If something breaks, `bin/rails dartsass:build` and `bin/rails assets:precompile`
are the two commands that will tell you the most, in that order.

---

## 9. Worth reading

- [Rails Upgrade Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html) — the `load_defaults` mechanism explained properly
- [Propshaft README](https://github.com/rails/propshaft) — short, and the "compared to Sprockets" section is the fastest way to understand the philosophy shift
- [dartsass-rails README](https://github.com/rails/dartsass-rails)
- [Heroku Ruby Support](https://devcenter.heroku.com/articles/ruby-support-reference) — the supported-versions table you'll need to check again in a year
- [Deploying Rails to Heroku](https://devcenter.heroku.com/articles/getting-started-with-rails7)
