# Phoenix image classification in a single file

> Powered by Elixir's Nx/Axon library [Bumblebee](https://github.com/elixir-nx/bumblebee)

Run with:

```console
elixir run.exs
```

## Deploy single file on fly.io

First, install the `fly` cli:

On MacOS:

```shell
brew install flyctl
```

On Linux:

```shell
curl -L https://fly.io/install.sh | sh
```

On Windows:

```shell
iwr https://fly.io/install.ps1 -useb | iex
```

Next, create a new app with `fly` on the command line:


```shell
fly create my-new-app
```

Finally, update the first line of the `fly.toml` to use your new app name: `app = "my-new-app"`

Now you can `fly deploy` and access your application at `my-new-app.fly.dev`.