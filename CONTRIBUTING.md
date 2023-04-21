# Contributing Guidelines

Thank you for considering contributing to our project! We welcome contributions from everyone. Before getting started, please take a moment to read our guidelines.

## How to contribute

1. Fork the repository.
2. Create a new branch for your contribution.
3. Make your changes and commit them.
4. Push your changes to your fork.
5. Submit a pull request.

## Reporting bugs

If you find a bug, please let us know by opening an issue. Be as detailed as possible when describing the issue, including any steps to reproduce the bug. If applicable, please provide your `modloader.log` file from the `user://` (Godot app_userdata) folder. This file contains valuable information that can help us identify the cause of the issue.

## Suggesting features

If you have an idea for a new feature or improvement, please open an issue to discuss it. We welcome all suggestions and will consider them carefully.

## Coding style

Please follow the [Godot 3.5 coding conventions for GDScript](https://docs.godotengine.org/en/3.5/tutorials/scripting/gdscript/gdscript_styleguide.html)

In addition, please follow these guidelines:

### Naming Convention
- Prefix local (private) to file vars / functions with `_`
- Prefix classes that should only be used by the ModLoader with `_`
- If a method is in a non-prefixed class and ModLoader Internal, but used outside of the private scope, prefix with `_`, use it outside the scope, but add a comment why it was used there

Reasoning:
1. Underscore methods/vars should only be used within the same file
2. Most classes should not be used by mods, only by the ModLoader. if they are prefixed with an underscore, no mod should access them and we are free to change the internal structure without breaking mods and needing deprecations
3. In some cases we need to use private methods outside of their file (`_rotate_log_file` for example) and the class is a public one (`ModLoaderLog` here). Since the method should not be accessible to mods, we are using a "private" method outside of its scope here - and that needs an explanation

### String Standards
- Double quotes over single quotes: `"string"`, not `'string'`
- Quote escaping over single quotes : `"\"hello\" world"`, not `'"hello" world'`
- Format strings over string concatenation and `str()`: `"hello %s!" % place`, not `"hello " + place + "!"`, not `str("hello", place)`. Except for very simple cases/single concatenation: `"hello " + place`, not `"hello %s" % place`
- split long strings into shorter ones with string concatenation `"" + "" + ...`, not `str("", "", ...)`
```gdscript
ModLoaderLog.info(
   "pretend that this" +
   "is a really long" +
   "message"
)
```

## Documentation

The documentation for this project is located in the repository's wiki. Please make sure to update the relevant documentation pages when making changes to the code. If you're not sure what needs to be updated, please ask in your pull request or issue.
*Note that you will mostly edit the [Upcoming Features](https://github.com/GodotModding/godot-mod-loader/wiki/Upcoming-Features) page, where all changes to the dev branch are documented until they become part of the next major update.*

## Communicating over Discord
We use Discord for communication and collaboration. You can join our Discord server at [discord.godotmodding.com](https://discord.godotmodding.com). Please use appropriate channels for your discussions and keep conversations respectful and on-topic.

## Licensing

All contributions must be licensed under the same license as the project. By contributing, you agree to license your contributions under the same terms.

## Thank you!

We appreciate your contributions and look forward to working with you.