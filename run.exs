host = if app = System.get_env("FLY_APP_NAME"), do: "#{app}.fly.dev", else: "localhost"

Application.put_env(:phoenix, :json_library, Jason)
Application.put_env(:phoenix_demo, PhoenixDemo.Endpoint,
  url: [host: host],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  server: true,
  live_view: [signing_salt: :crypto.strong_rand_bytes(8) |> Base.encode16()],
  secret_key_base: :crypto.strong_rand_bytes(32) |> Base.encode16(),
  pubsub_server: PhoenixDemo.PubSub
)

Mix.install([
  {:plug_cowboy, "~> 2.6"},
  {:jason, "~> 1.4"},
  {:phoenix, "~> 1.7.0-rc.0", override: true},
  {:phoenix_live_view, "~> 0.18.3"},
  {:bumblebee, "~> 0.1.0"},
  {:nx, "~> 0.4.1"},
  {:exla, "~> 0.4.1"}
])

Application.put_env(:nx, :default_backend, EXLA.Backend)

defmodule PhoenixDemo.Layouts do
  use Phoenix.Component

  def render("live.html", assigns) do
    ~H"""
    <script src="//cdn.jsdelivr.net/npm/phoenix@1.7.0-rc.0/priv/static/phoenix.min.js"></script>
    <script src="//cdn.jsdelivr.net/npm/phoenix_live_view@0.18.3/priv/static/phoenix_live_view.min.js"></script>
    <script>
      const ImageInput = {
        mounted(){
          const DROP_CLASSES = ["bg-blue-100", "border-blue-300"]
          this.boundHeight = parseInt(this.el.dataset.height)
          this.boundWidth = parseInt(this.el.dataset.width)
          this.inputEl = this.el.querySelector(`#${this.el.id}-input`)
          this.previewEl = this.el.querySelector(`#${this.el.id}-preview`)

          this.el.addEventListener("click", e => this.inputEl.click())
          this.inputEl.addEventListener("change", e => this.loadFile(event.target.files))
          this.el.addEventListener("dragover", e => {
            e.stopPropagation()
            e.preventDefault()
            e.dataTransfer.dropEffect = "copy"
          })
          this.el.addEventListener("drop", e => {
            e.stopPropagation()
            e.preventDefault()
            this.loadFile(e.dataTransfer.files)
          })
          this.el.addEventListener("dragenter", e => this.el.classList.add(...DROP_CLASSES))
          this.el.addEventListener("drop", e => this.el.classList.remove(...DROP_CLASSES))
          this.el.addEventListener("dragleave", e => {
            if(!this.el.contains(e.relatedTarget)){ this.el.classList.remove(...DROP_CLASSES) }
          })
        },

        loadFile(files){
          const file = files && files[0]
          if(!file){ return }
          const reader = new FileReader()
          reader.onload = (readerEvent) => {
            const imgEl = document.createElement("img")
            imgEl.addEventListener("load", (loadEvent) => {
              this.setPreview(imgEl)
              const blob = this.canvasToBlob(this.toCanvas(imgEl))
              this.upload("image", [blob])
            })
            imgEl.src = readerEvent.target.result
          }
          reader.readAsDataURL(file)
        },

        setPreview(imgEl){
          const previewImgEl = imgEl.cloneNode()
          previewImgEl.style.maxHeight = "100%"
          this.previewEl.replaceChildren(previewImgEl)
        },

        toCanvas(imgEl){
          // We resize the image, such that it fits in the configured height x width, but
          // keep the aspect ratio. We could also easily crop, pad or squash the image, if desired
          const canvas = document.createElement("canvas")
          const ctx = canvas.getContext("2d")
          const widthScale = this.boundWidth / imgEl.width
          const heightScale = this.boundHeight / imgEl.height
          const scale = Math.min(widthScale, heightScale)
          canvas.width = Math.round(imgEl.width * scale)
          canvas.height = Math.round(imgEl.height * scale)
          ctx.drawImage(imgEl, 0, 0, imgEl.width, imgEl.height, 0, 0, canvas.width, canvas.height)
          return canvas
        },

        canvasToBlob(canvas){
          const imageData = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height)
          const buffer = this.imageDataToRGBBuffer(imageData)
          const meta = new ArrayBuffer(8)
          const view = new DataView(meta)
          view.setUint32(0, canvas.height, false)
          view.setUint32(4, canvas.width, false)
          return new Blob([meta, buffer], {type: "application/octet-stream"})
        },

        imageDataToRGBBuffer(imageData){
          const pixelCount = imageData.width * imageData.height
          const bytes = new Uint8ClampedArray(pixelCount * 3)
          for(let i = 0; i < pixelCount; i++) {
            bytes[i * 3] = imageData.data[i * 4]
            bytes[i * 3 + 1] = imageData.data[i * 4 + 1]
            bytes[i * 3 + 2] = imageData.data[i * 4 + 2]
          }
          return bytes.buffer
        }
      }
      const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {hooks: {ImageInput}})
      liveSocket.connect()
    </script>
    <script src="https://cdn.tailwindcss.com"></script>
    <%= @inner_content %>
    """
  end
end

defmodule PhoenixDemo.ErrorView do
  def render(_, _), do: "error"
end

defmodule PhoenixDemo.SampleLive do
  use Phoenix.LiveView, layout: {PhoenixDemo.Layouts, :live}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(label: nil, running: false, task_ref: nil)
     |> allow_upload(:image,
       accept: :any,
       max_entries: 1,
       max_file_size: 300_000,
       progress: &handle_progress/3,
       auto_upload: true
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen w-screen flex items-center justify-center antialiased bg-gray-100">
      <div class="flex flex-col items-center w-1/2">
        <h1 class="text-slate-900 font-extrabold text-3xl tracking-tight text-center">Elixir image classification demo</h1>
        <p class="mt-6 text-lg text-slate-600 text-center max-w-3xl mx-auto">
          Powered by <a href="https://github.com/elixir-nx/bumblebee" class="font-mono font-medium text-sky-500">Bumblebee</a>,
          an Nx/Axon library for pre-trained and transformer NN models with 🤗 integration.
          Deployed on <a href="https://fly.io" class="font-mono font-medium text-sky-500">fly.io</a> dedicated-cpu-1x.
        </p>
        <form class="m-0 flex flex-col items-center space-y-2 mt-8" phx-change="noop" phx-submit="noop">
          <.image_input id="image" upload={@uploads.image} height={224} width={224} />
        </form>
        <div class="mt-6 flex space-x-1.5 items-center text-gray-600 text-xl">
          <span>Label:</span>
          <%= if @running do %>
            <.spinner />
          <% else %>
            <span class="text-gray-900 font-medium"><%= @label || "?" %></span>
          <% end %>
        </div>
        <p class="text-lg text-center max-w-3xl mx-auto fixed top-2 right-2">
          <a href="https://github.com/chrismccord/signle_file_phoenix_bumblebee_ml" class="ml-6 text-sky-500 hover:text-sky-700 font-mono font-medium">
            View the source
            <span class="sr-only">view source on GitHub</span>
            <svg viewBox="0 0 16 16" class="inline w-6 h-6" fill="currentColor" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"></path></svg>
          </a>
        </p>
      </div>
    </div>
    """
  end

  defp image_input(assigns) do
    ~H"""
    <div
      id={@id}
      class="inline-flex p-4 border-2 border-dashed border-gray-200 rounded-lg cursor-pointer bg-white"
      phx-hook="ImageInput"
      data-height={@height}
      data-width={@width}
    >
      <.live_file_input upload={@upload} class="hidden" />
      <input id={"#{@id}-input"} type="file" class="hidden" />
      <div
        class="h-[300px] w-[300px] flex items-center justify-center"
        id={"#{@id}-preview"}
        phx-update="ignore"
      >
        <div class="text-gray-500 text-center">
          Drag an image file here or click to open file browser
        </div>
      </div>
    </div>
    """
  end

  defp spinner(assigns) do
    ~H"""
    <svg phx-no-format class="inline mr-2 w-4 h-4 text-gray-200 animate-spin fill-blue-600" viewBox="0 0 100 101" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z" fill="currentColor" />
      <path d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z" fill="currentFill" />
    </svg>
    """
  end

  def handle_progress(:image, entry, socket) do
    if entry.done? do
      socket
      |> consume_uploaded_entries(:image, fn meta, _ -> {:ok, File.read!(meta.path)} end)
      |> case do
        [binary] ->
          image = decode_as_tensor(binary)
          task = Task.async(fn -> Nx.Serving.batched_run(PhoenixDemo.Serving, image) end)
          {:noreply, assign(socket, running: true, task_ref: task.ref)}

        [] ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp decode_as_tensor(<<height::32-integer, width::32-integer, data::binary>>) do
    data |> Nx.from_binary(:u8) |> Nx.reshape({height, width, 3})
  end

  # We need phx-change and phx-submit on the form for live uploads
  def handle_event("noop", %{}, socket) do
    {:noreply, socket}
  end

  def handle_info({ref, result}, %{assigns: %{task_ref: ref}} = socket) do
    Process.demonitor(ref, [:flush])
    %{predictions: [%{label: label}]} = result
    {:noreply, assign(socket, label: label, running: false)}
  end
end

defmodule PhoenixDemo.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", PhoenixDemo do
    pipe_through(:browser)

    live("/", SampleLive, :index)
  end
end

defmodule PhoenixDemo.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_demo

  socket("/live", Phoenix.LiveView.Socket)
  plug(PhoenixDemo.Router)
end

# Application startup

{:ok, model_info} = Bumblebee.load_model({:hf, "microsoft/resnet-50"})
{:ok, featurizer} = Bumblebee.load_featurizer({:hf, "microsoft/resnet-50"})

serving =
  Bumblebee.Vision.image_classification(model_info, featurizer,
    top_k: 1,
    compile: [batch_size: 10],
    defn_options: [compiler: EXLA]
  )

# Dry run for copying cached mix install from builder to runner
if System.get_env("EXS_DRY_RUN") == "true" do
  System.halt(0)
else
  {:ok, _} =
    Supervisor.start_link(
      [
        {Phoenix.PubSub, name: PhoenixDemo.PubSub},
        PhoenixDemo.Endpoint,
        {Nx.Serving, serving: serving, name: PhoenixDemo.Serving, batch_timeout: 100}
      ],
      strategy: :one_for_one
    )

  Process.sleep(:infinity)
end
