## 1.4.0

- Implemented annotation sharing: Shift-click any annotation to share it in the chat. Of course, only StR users will be able to import it.
- Added account-level map annotations: There is now a checkbox under map annotations to make them visible across all characters.
- Improved clustering: overview clusters are now interactive, map pins will now also cluster, and cluster tooltips have more predictable ordering.
- Improved projections of annotations inside capital cities and battlegrounds: Both now project into their zone instead of directly on Azeroth. In practice, it means a quest inside Stormwind will start appearing in Elwynn Forest too, on top of the Stormwind area.

## 1.3.0

- Sorry, no new features in this one!
- Configured the addon for publication on Wago and WoWUp

## 1.2.1

- By default, the addon will now stay **enabled** when Blizzard's Quest Objectives are enabled: With the previous default, a new user could be confused why the addon was not working. You had to know the feature exist to think about disabling Quest Objectives.

## 1.2.0

- Made clusters interactive: Now you can click a cluster to bring up its annotations. The annotations respond to the usual interactions.
- Improved annotation pins to look more like the default Blizzard quest pins.
- Added an indicator beside annotated quests in the journal and objective tracker, similar to the default behavior if you enable Blizzard's Quest Objectives.
- Added an option to effectively disable the addon when Blizzard's Quest Objectives are enabled.

## 1.1.0

- Extended clustering to quest annotations outside of overview: It was messy having a bunch of annotations for the same location, so now they are clustered under a single pin. It shouldn't change much in typical use. Interactive clusters will be coming soon and will improve on this.

## 1.0.0

- Initial version with:
    - Journal and map integration for quest annotations
    - Support for multi-map quest annotations
    - Option to auto-delete quest annotations after turn-in
    - Filter to show annotations on parent maps
