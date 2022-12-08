# Phoenix image classification in a single file

> Powered by Elixir's Nx/Axon library [Bumblebee](https://github.com/elixir-nx/bumblebee)

View the live [demo](https://phx-ml-example.fly.dev).

![2022-12-08 13-56-25 2022-12-08 13_58_57](https://user-images.githubusercontent.com/576796/206543644-bca409f1-a2d9-4519-906c-c6d584f93339.gif)


Run locally with `$ elixir run.exs`, and access your app at [http://localhost:4000](http://localhost:4000)

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
