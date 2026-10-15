/**
 * Region — region data model (source: feature/user/model/Region.kt).
 *
 * @property id region id
 * @property name region name
 * @property children child regions (empty for a leaf)
 */
export class Region {
  id: string = '';
  name: string = '';
  children: Region[] = [];

  constructor(id: string = '', name: string = '', children: Region[] = []) {
    this.id = id;
    this.name = name;
    this.children = children;
  }
}
