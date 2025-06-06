# Stitch Fundamentals

Stitch is a visual programming and prototyping tool. You build behavior by wiring **patches** (logic nodes) together on the **Patch Canvas** and drive **layers** (visual nodes) in the **Layer Sidebar**. Changes appear live in the Prototype Preview window.

## Patch Canvas

The Patch Canvas is your logic workspace:

* **Patches** – self‑contained nodes with typed input and output ports.
* **Edges** – drag from an output to any compatible input to send data each frame.
* **Groups** – wrap a set of patches into a single collapsible node to keep large graphs tidy.
* **Wireless Broadcaster / Receiver** – pass values across the canvas without drawing edges.
* **Search** – press `CMD` + `ENTER` to open the node browser.

![StitchUI](Guides_Assets/StitchUI.png)

## Layer Sidebar

The Layer Sidebar shows every visual element as a hierarchical list:

* Drag to reorder – the list order matches the front‑to‑back draw order.
* Nest layers to create **Layer Groups** for collective transforms and clipping.
* Hover any item to view its corresponding layer in the prototype previewer.
* Right‑click a layer for quick actions such as rename, group, or get more info.

![LayerSideBarGrouping](Guides_Assets/LayerSidebarGrouping.gif)

## Preview Window

The Preview Window renders your prototype exactly as it will appear on‑device. Interact with it to trigger gestures or keyboard events that flow back into the canvas.

![PreviewWindow](Guides_Assets/PreviewWindow.gif)

## Typical Workflow

1. Lay out your interface in the Layer Sidebar.
2. Wire behavior on the Patch Canvas.
3. Drag a patch output onto a layer property to bind them.
4. Iterate in real time; adjust values until it feels right.
5. Use Groups and wireless patches to keep the graph readable.

These three surfaces—Patch Canvas, Layer Sidebar, and Preview—form the core mental model of Stitch. Master them and you can build almost anything without writing code.

## Stitch AI

Stitch AI builds graphs using natural language. It is accessed from the Node menu.

At this moment, Stitch AI is limited to building smaller components (usually less than 6 nodes).

### Data Collection

Sharing a few safe, anonymous signals lets us fix issues quickly and train Stitch AI to suggest the right nodes more often. You can always opt out from App Settings.

Exactly what we collect:
1. Strings of AI queries from the Node menu.
2. Logs from failed results.
3. AI results from successful response.
4. Any review feedback you choose to submit.
