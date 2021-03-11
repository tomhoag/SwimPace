# SwimPace

<figure class="video_container">
  <video width="640" controls="true" allowfullscreen="false" poster="http://squarepisoftware.com/wp-content/uploads/swimpacedemo.png">
    <source src="http://squarepisoftware.com/wp-content/uploads/swimpacedemo.mp4" type="video/mp4">
  </video>
</figure>

This app overlays a pace bar on a swim meet livestream or video (or really any livestream or video but it probably doesn't have much utility?)

The plan was to use the window of this app as input to Open Broadcaster Software ([OBS](https://obsproject.com)) 

### Why?

I didn't quite get this project complete in time for some of the livestreaming of my son's swim meets.  It was just a little side project to see how this could be done.

### How to 

1. Run the app
2. Select an input source from the `Video Input` menu.  All available camera inputs should be listed.  You can also open an mp4 from file.
3. Configure the pool edges.  If the yellow pool edge lines don't appear, turn them on using `Config->Show Pool Outline`
4. Drag the ends of the lines (not the yellow dots) to the pool edges.  When you mouse near the end of a line, a selection pad will appear.  When you click and drag the pad, it will magnify the image under the selection pad. 
5. The edges only need to be overlaid on part of the pool edge or lane markers.  The intersection of the edge lines will be determined and the yellow dots will move to the pool corners.  This is handy in the event that your camera image does not contain the corners.
6. Be certain that the line labeled 'Start' is at the starting block end of the pool, 'Turn' is at the opposite of 'Start'.  The 'Right' line should be on the right side of the pool as though you are standing behind the blocks looking at the turn. 'Left' should be opposite 'Right'.
5. Once you have the edges defined, you can turn them off using the Config menu `Config->Show Pool Outline`
6. To config specifics for the pace line, select `Config->Pool & Race`
7. Set up the specifics for the race distance and pace to be displayed, specifics about the pool, and configuration of the pace bar color and label.  
8. Turn the pace bar to visible now or you can wait until after the race has begun.
9. Close the config window.
10. When the race begins, select `Config->Start'
11. If you didn't previously make the pace bar visibile, you can do so any time from `Config->Pace Bar Visible`. You can remove the pace bar from view using the same menu pick.

The pace bar will move at a constant pace for the duration of the race.  When the pace bar "completes" the distance, it will disappear from view.

### Notes

* The app does *not* track the edges of the pool.  If the camera moves, you will need to reset the pool edges.  Moving the camera during the race is not advised.

### To Do

* Save the pool edge configuration between runs of the app.  Easy enough, just ran out of time.

* Do some cool machine vision stuff and track the edges of the pool so the camera can be moved about during a race.

* Do some more cool machine vision stuff and don't draw the pace bar over coaches, the starter and other people near the pool edge.

* The pace layer sometimes moves a bit clunky as too much is happening on the main thread.  Need to background some of the functionality.

* The drawing makes heavy use of CAShapeLayers, CATextLayers and CALayers in general.  If necessary, erformance could likely be improved using other techniques.

### The Demo

Here's a rather long demo showing how to configure the pool edges and view the pace bar.  This was completed during warm-up/cool-down so while the pace bar appears, who needs a pace bar for a warm-up? :-)



