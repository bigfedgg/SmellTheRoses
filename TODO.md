# TODO

- [ ] Add demonstration video to README.md
- [ ] Add CurseForge link to README.md
- [ ] Test navigation with completed but not turned-in quest
- [ ] Delete markers for completed quests
  - Add a native configuration panel under WoW's options
  - The configuration panel should allow to toggle marker deletion on quest completion
  - The configuration panel should have a button to remove existing annotations for completed quests 
- [ ] Add an option to toggle annotation overview in the native Map Filter dropdown in the map panel
  - Call it "Smell the Roses"
  - When disabled annotations are only shown on their direct map, or when a quest is focused
  - When enabled annotations are shown on every parent, with clustering
    - Clustering is applied on the final projected pins and doesn't take into account ancestry links
    - We can start with some arbitrary clustering distance and then adjust if needed
    - Clusters should show a segmented tooltip, each segment has title + 2 lines of body, instructions after segments
    - Clusters are not editable
    - Clicking a cluster doesn't do anything