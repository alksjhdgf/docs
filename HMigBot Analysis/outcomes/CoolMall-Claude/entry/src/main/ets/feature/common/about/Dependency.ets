/**
 * Dependency (source: feature/common/model/Dependency.kt) — a third-party library shown in the
 * `引用致谢` sheet.
 */
export class Dependency {
  /** Library name */
  name: string = '';
  /** Library version */
  version: string = '';
  /** Library description */
  description: string = '';
  /** Official website url */
  websiteUrl: string = '';
  /** Library category */
  category: string = '';

  constructor(name: string = '', version: string = '', description: string = '', websiteUrl: string = '',
    category: string = '') {
    this.name = name;
    this.version = version;
    this.description = description;
    this.websiteUrl = websiteUrl;
    this.category = category;
  }
}
