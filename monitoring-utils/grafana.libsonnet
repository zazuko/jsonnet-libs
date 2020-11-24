{
  local util = self,
  prefixTitle(prefix): {
    title: prefix + super.title,
  },
  addTags(tags): {
    tags+: tags,
  },
  addTag(tag): util.addTags([tag]),
  augmentDashboards(mixin, what): mixin {
    grafanaDashboards+: std.mapWithKey(
      function(name, dashboard) dashboard + what,
      (mixin { grafanaDashboards+: {} }).grafanaDashboards
    ),
  },
}
