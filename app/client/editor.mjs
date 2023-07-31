// import * as autocomplete from "@codemirror/autocomplete"
import {EditorView, basicSetup } from "codemirror"
import { keymap } from "@codemirror/view"

// Custom extensions
import { toggleFile, markField, sentenceHover } from "./cm-extensions"

// FileManager
import { fileManager, filePanelExt } from "./fileManager.ts"

// Squirrel worker
import { SquirrelWorker } from "./squirrel-worker.ts"

// Load language syntax
import { Squirrel } from "./squirrel.js"

let worker = new SquirrelWorker(fileManager,new URL('./client.js', window.location));

fileManager.bindWorker(worker);

function squirrelKeymap(view) {
  return keymap.of([{
    key: "Ctrl-Enter",
    any(view,e) { 
      if (e.key == "Enter" && e.ctrlKey) {
        worker.execToCursor(view)
        return true
      }
      if (e.key == "ArrowUp" && e.ctrlKey) {
        worker.undo(1)
        return true
      }
      if (e.key == "ArrowDown" && e.ctrlKey) {
        worker.execNextSentence(view)
        return true
      }
      return false 
    }
  }])
}

let updateListenerExtension = EditorView.updateListener.of((update) => {
  if (update.docChanged) {
    //Boolean for system file
    fileManager.dirty = true; 
    worker.updateCursor(update)
  }
});

let myview = new EditorView({
  doc:"include Basic.\n"
+"system null.type T.\n"
+"op yo : T -> T = fun(x : T) => x.\n"
+"goal foo : empty <> empty.\n"
+"Proof.\n"
+" congruence.\n"
+" admit.\n"
+"Qed."
  ,
  extensions: [
    updateListenerExtension,
    worker.simpleLezerLinter(),
    squirrelKeymap(),
    sentenceHover,
    basicSetup,
    markField,
    filePanelExt(),
    Squirrel()
  ],
  parent: input
})

//Buttons

// bind buttons 
var buttonToCursor = document.getElementById('to-cursor');
buttonToCursor.onclick = function() { 
  worker.execToCursor(myview);
  return false; 
}

var buttonReset = document.getElementById('reset');
buttonReset.onclick = function() { 
  worker.reset(myview);
  return false; 
}

var buttonInfo = document.getElementById('info');
buttonInfo.onclick = function() { 
  worker.info();
  return false; 
}

var buttonUp = document.getElementById('up');
buttonUp.onclick = function() { 
  worker.undo(1)
  return false; 
}

var buttonDown = document.getElementById('down');
buttonDown.onclick = function() { 
  worker.execNextSentence(myview)
  return false; 
}

worker.launch()