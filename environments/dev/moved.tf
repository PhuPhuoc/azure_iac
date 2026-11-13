# modules/headless-cms was renamed to modules/cms with no content changes.
# This rewrites the whole module state subtree; resources are NOT recreated.
moved {
  from = module.headless_cms
  to   = module.cms
}
