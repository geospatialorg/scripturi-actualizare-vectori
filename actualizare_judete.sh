#1. Județe poligon 
#filtrare cîmpuri din fișierul ANCPI și scriere fișier .prj
ogr2ogr -f "SQLite" -a_srs "EPSG:3844" -lco LAUNDER=NO judete.db /home/earth/data/vector/limite_administrative/Administrative_unit_2nd_Order.shp

#încărcare tabel regiuni de dezvoltare în SQLITE
csvsql --db sqlite:///judete.db --insert /home/earth/data/tabel/siruta_zone.csv

#încărcare tabel județe în SQLITE
csvsql --db sqlite:///judete.db --insert /home/earth/data/tabel/siruta_judete.csv

ogr2ogr -f "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ro_judete_poligon -sql "SELECT b.jud AS countyId, b.siruta AS countyCode, b.denj AS name, b.mnemonic, c.zona AS regionId, c.denzona AS region, b.pop1948, b.pop1956, b.pop1966, b.pop1977, b.pop1992, b.pop2002, b.pop2011, b.FSJ AS sortCode, a.beginvers AS version, a.GEOMETRY FROM Administrative_unit_2nd_Order AS a LEFT JOIN siruta_judete AS b ON (a.natcode = b.siruta) LEFT JOIN siruta_zone AS c ON (b.zona=c.zona)" judete.db judete.db

#creare fișiere Esri Shapefile
ogr2ogr -lco ENCODING=UTF-8 -a_srs EPSG:3844 -sql "SELECT * FROM ro_judete_poligon" ro_judete_poligon.shp judete.db

#arhivare fișiere shp
zip ro_judete_poligon.zip ro_judete_poligon.*

#creare versiune GeoPackage
ogr2ogr -f GPKG -a_srs EPSG:3844 ro_judete_poligon.gpkg ro_judete_poligon.shp

#creare versiune GeoJSON
ogr2ogr -f GeoJSON -s_srs EPSG:3844 -t_srs EPSG:4326 ro_judete_poligon.geojson ro_judete_poligon.shp

#creare versiune KML
ogr2ogr -f KML -s_srs EPSG:3844 -t_srs EPSG:4326 -dsco NameField=name ro_judete_poligon.kml ro_judete_poligon.shp

#copiere fișiere în directorul de download
cp -rf ro_judete_poligon.zip ro_judete_poligon.gpkg ro_judete_poligon.geojson ro_judete_poligon.kml /var/www/geospatial/files/vector/limite_administrative/judete

#actualizarea setului de date în baza de date PostGIS
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=user dbname=geospatial password=password" -lco schema=romania -lco overwrite=yes  -lco LAUNDER=NO ro_judete_poligon.shp ro_judete_poligon -a_srs EPSG:3844 -skipfailures -overwrite

#actualizarea metadatelor din serviciile de date
curl -u user:password -XPUT -H "Content-type: text/xml" -d "<featureType><abstract>Setul de date cuprinde limitele de județ (geometrie poligon). Actualizare 23.03.2016. Sursa ANCPI.</abstract><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/geospatial/datastores/geospatial_romania/featuretypes/ro_judete_poligon


#2. Județe polilinie
ogr2ogr  -append -a_srs "EPSG:3844" -f "SQLite" judete.db /home/earth/data/vector/limite_administrative/Administrative_boundary_2nd_Order.shp


sqlite3 judete.db "CREATE TABLE split_siruta AS SELECT id, substr(localid, 1, instr(localid, '.') - 1) AS leftId, substr(localid, instr(localid, '.') + 1) AS rightId FROM administrative_boundary_2nd_order"

ogr2ogr -f "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ro_judete_polilinie -sql "SELECT a.id, c.name AS leftCounty, d.name AS rightCounty, b.leftId, b.rightId, a.beginvers AS version, a.GEOMETRY FROM Administrative_boundary_2nd_Order AS a LEFT JOIN split_siruta AS b ON (a.id = b.id) LEFT JOIN ro_judete_poligon AS c ON (b.leftId=c.countycode) LEFT JOIN ro_judete_poligon AS d ON (b.rightId=d.countycode)" judete.db judete.db

#creare fișiere Esri Shapefile
ogr2ogr -lco ENCODING=UTF-8 -a_srs EPSG:3844 -sql "SELECT * FROM ro_judete_polilinie" ro_judete_polilinie.shp judete.db

#arhivare fișiere shp
zip ro_judete_polilinie.zip ro_judete_polilinie.*

#creare versiune GeoPackage
ogr2ogr -f GPKG -a_srs EPSG:3844 ro_judete_polilinie.gpkg ro_judete_polilinie.shp

#creare versiune GeoJSON
ogr2ogr -f GeoJSON -s_srs EPSG:3844 -t_srs EPSG:4326 ro_judete_polilinie.geojson ro_judete_polilinie.shp

#creare versiune KML
ogr2ogr -f KML -s_srs EPSG:3844 -t_srs EPSG:4326 -dsco NameField=name ro_judete_polilinie.kml ro_judete_polilinie.shp

#copiere fișiere în directorul de download
cp -rf ro_judete_polilinie.zip ro_judete_polilinie.gpkg ro_judete_polilinie.geojson ro_judete_polilinie.kml /var/www/geospatial/files/vector/limite_administrative/judete

#actualizarea setului de date în baza de date PostGIS
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=user dbname=geospatial password=password" -lco schema=romania -lco overwrite=yes -lco LAUNDER=NO ro_judete_polilinie.shp ro_judete_polilinie -a_srs EPSG:3844 -skipfailures -overwrite

#actualizarea metadatelor din serviciile de date
curl -u user:password -XPUT -H "Content-type: text/xml" -d "<featureType><abstract>Setul de date cuprinde limitele de județ (geometrie polilinie). Actualizare 23.03.2016. Sursa ANCPI.</abstract><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/geospatial/datastores/geospatial_romania/featuretypes/ro_judete_polilinie

rm ro_judete*.* judete.db
