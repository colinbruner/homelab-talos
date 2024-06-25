# Config

Before beginning review [patching](./patching.md) to get a basic understanding of the types of patches accepted by Talos.

## ytt
The following are components of [ytt](https://github.com/carvel-dev/ytt), a yaml templating tool that was use to generate Talos patches and configurations.

### Schema
The schema for the purposes of this configuration can be found within the [values](../values) directory, at [values/schema.yml](../values/schema.yml)

The schema defines variables can be passed in values and written to templates. 

For more information about writing a schema, check out ytt's documentation for [schema][schema]

### Templates

The templates directory contains two sub-directories, each with two sets of templates.
- control/strategic-patch.yaml
- control/json-patch.yaml
- worker/strategic-patch.yaml
- worker/json-patch.yaml




### Values

[schema]: https://carvel.dev/ytt/docs/v0.49.x/how-to-write-schema/