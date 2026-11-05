## 1.5.2

- Quick fix to Spoken integration

## 1.5.1

- Fixed how map clicks are handled. Should make the addon completely taint-free now.

## 1.5.0

This is probably the last update before launch. It changes a lot of behavior to make it as close to Blizzard as possible. It also fixes some taint issues that could break the UI when the addon was enabled. I've leveled with this version and found it to be very enjoyable and easy to use!

- Implemented "Turn-in" annotations: Mark an annotation as "Turn-in" by editing it and toggling the "?" button. It will then stay hidden until you complete the quest. You can always show all annotations by clicking the quest in the journal.
- Changed the global annotations checkbox into a button toggle similar to the quest annotation toggle described above. Just to keep the UI consistent.
- Improved quest tooltips: They now display incomplete objectives and use the proper difficulty color for quest titles.
- Removed expandable clusters: I really didn't like them! Instead, I now use the same technique Blizzard uses to separate close pins by slightly pushing them away from each other.
- Simplified quest annotation display logic: Quest annotations can't be placed directly on continent maps or on the world map anymore. This is mainly to keep the same behavior as Blizzard quest objectives. Don't worry, this only applies to new quest annotations you add.
- Improved annotation positioning: You will now see annotations from neighboring maps. For example, if you open the Westfall map, you will be able to see annotations in the west of Elwynn Forest as that part of the map is still visible to you.
- Changed the "Annotation Overview" filter to only apply to map annotations: This is mainly to avoid having to deal with clustering as the higher we go in map levels, the closer pins get naturally.
- Fixed a visual bug in the quest journal when using StR with Spoken. The play button doesn't overlap quest indicators anymore.
- Fixed Lua errors that could result from tainting.

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
