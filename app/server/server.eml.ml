let home =
  <html>
    <body id="body" =class"jsquirrel-main">
      <link rel="stylesheet" href="/static/jsquirreldoc.css">
      <link rel="stylesheet" href="/static/squirrel-base.css">
      <link rel="stylesheet" href="/static/squirrel-light.css">
      <link rel="stylesheet" href="/static/ide-base.css">
      <link rel="stylesheet" href="/static/visualisation_style.css">
      <script src="https://d3js.org/d3.v5.min.js"></script>

      <div id="ide-wrapper" class="jsquirrel-ide layout-flex goals-active">
        <div class="jsquirrel" id="input"></div>
        <div id="panel-wrapper" class="jsquirrel-theme-light">
          <div id="toolbar">
            <span id="buttons">
              <button id="down" name="down" alt="Ctrl-Down" 
              title="Ctrl-Down"></button>
              <button id="up" name="up" alt="Ctrl-Up" 
              title="Ctrl-Up"></button>
              <button id="to-cursor" name="to-cursor" alt="Ctrl-Enter" 
              title="Ctrl-Enter"></button>
              <button id="reset" name="reset" alt="Reset Worker" 
              title="Reset Worker"></button>
              <button id="info" name="info" alt="Info Worker" 
              title="Info Worker"></button>
            </span>
          </div>
          <div class="flex-container">
            <div id="goal-panel" class="flex-panel">
              <div id="goal-text" class="content">Loading, please wait...</div>
            </div>
            <div id="visu-panel" class="flex-panel">
              <script src="/static/visualisation_script.js"></script>
            </div>
            <div class="msg-area flex-panel">
              <div id="query-panel" class="content show-Error
              show-Warning show-Notice show-Info"></div>
            </div>
          </div>
        </div>
      </div>
      <script id="bundle" src="/static/editor.bundle.js"></script>
    </body>
  </html>

let () =
  Dream.run
  @@ Dream.logger
  @@ Dream.router [

    Dream.get "/"
      (fun _ -> Dream.html home);

    Dream.get "/static/**"
      (Dream.static "app/static");
  ]
