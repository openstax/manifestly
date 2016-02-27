[![Gem Version](https://badge.fury.io/rb/manifestly.svg)](http://badge.fury.io/rb/manifestly)
[![Build Status](https://travis-ci.org/openstax/manifestly.svg?branch=master)](https://travis-ci.org/openstax/manifestly)

# Manifestly

Manifestly helps you manage complicated deployments involving multiple sites and git repositories.

## Installation

Manifestly is run as a standalone executable.  Install with:

    $ gem install manifestly

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install manifestly

## Usage

Manifestly has built in help:

    $ manifestly help

_Note_: underscores and hyphens are interchangeable in option names, e.g. `--search_paths=blah` is the same as `--search-paths=blah`.

### create

To create a new manifest, run

    $ manifestly create

Both `create` and `apply` take a `--search-paths` option to specify where the repositories of interest can be found.  The default search path is the current directory.

`create` by default is non-interactive (see `$>manifestly help create`) but there is an interactive option that will show you a blank manifest and give you options to add or remove repositories, or to choose the manifest commit for an existing repository.  When repositories are added, their latest commit is listed.  All commits seen during manifest creation are local commits only -- this tool does not look up remote commits.

### upload

To push a manifest file you have created, call:

    $ manifestly upload --local=my_file.manifest --mfrepo=myorg/myrepo --remote=foo

This will take your local file and push it as the latest commit on top of the `foo` file at github.com/myorg/myrepo.

### download

To download a manifest file... see built-in help (`$>manifestly help download`)

### apply

To apply a manifest file to your local repositories... instructions TBD, see built-in help.

    $ manifestly apply --file=20150919-210854-2d47.manifest

### list

To list available manifest files... instructions TBD, see built-in help

### tag

You can add a tag to a manifest.  The same tag can be added multiple times (under the covers, Manifestly adds some unique characters to the tag you provide).

See `$> manifestly help tag`.

### find

You can retrieve manifest SHAs for tags you've added.

See `$> manifestly help find`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To run manifestly like an end user eventually will, run:

```
exe/manifestly <OPTIONS AND ARGS HERE>
```

Remember to pass the `--search-paths` option to tell manifestly where to find your repositories relative to where you are running the gem from.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/manifestly/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
