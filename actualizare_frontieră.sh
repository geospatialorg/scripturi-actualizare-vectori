#1. Frontieră poligon 
#filtrare cîmpuri din fișierul ANCPI și scriere fișier .prj
ogr2ogr-lco ENCODING=UTF-8 -a_srs "EPSG:3844" -dialect sqlite -sql "SELECT a.Id AS id, a.country AS country, a.name AS name, a.beginVers AS version, a.Geometry FROM Administrative_unit_1st_Order AS a" ro_frontiera_poligon.shp /home/earth/data/vector/limite_administrative/Administrative_unit_1st_Order.shp

#actualizare cîmp id
/home/earth/kits/gdal-2.0.1/apps/ogrinfo ro_frontiera_poligon.shp -dialect SQLite -sql "UPDATE ro_frontiera_poligon SET id = 1"

#arhivare fișiere shp
zip ro_frontiera_poligon.zip ro_frontiera_poligon.*

#creare versiune GeoPackage
ogr2ogr-f GPKG -a_srs EPSG:3844 ro_frontiera_poligon.gpkg ro_frontiera_poligon.shp

#creare versiune GeoJSON
ogr2ogr-f GeoJSON -s_srs EPSG:3844 -t_srs EPSG:4326 ro_frontiera_poligon.geojson ro_frontiera_poligon.shp

#creare versiune KML
ogr2ogr-f KML -s_srs EPSG:3844 -t_srs EPSG:4326 -dsco NameField=name ro_frontiera_poligon.kml ro_frontiera_poligon.shp

#copiere fișiere în directorul de download
cp -rf ro_frontiera_poligon.zip ro_frontiera_poligon.gpkg ro_frontiera_poligon.geojson ro_frontiera_poligon.kml /var/www/geospatial/files/vector/limite_administrative/frontiera

#actualizarea setului de date în baza de date PostGIS
ogr2ogr-f "PostgreSQL" PG:"host=localhost user=username dbname=geospatial password=password" -lco schema=romania -lco overwrite=yes ro_frontiera_poligon.shp ro_frontiera_poligon -a_srs EPSG:3844 -skipfailures -overwrite

#actualizarea metadatelor din serviciile de date
curl -u username:password -XPUT -H "Content-type: text/xml" -d "<featureType><abstract>Setul de date cuprinde granița României (geometrie poligon). Actualizare 23.03.2016. Sursa ANCPI.</abstract><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/geospatial/datastores/geospatial_romania/featuretypes/ro_frontiera_poligon


#2. Frontieră polilinie
#filtrare cîmpuri din fișierul ANCPI și scriere fișier .prj
ogr2ogr-lco ENCODING=UTF-8 -a_srs "EPSG:3844" -dialect sqlite -sql "SELECT a.Id AS id, a.localId AS border, a.beginVers AS version, a.Geometry FROM Administrative_boundary_1st_Order AS a" ro_frontiera_polilinie.shp /home/earth/data/vector/limite_administrative/Administrative_boundary_1st_Order.shp

#arhivare fișiere shp
zip ro_frontiera_polilinie.zip ro_frontiera_polilinie.*

#creare versiune GeoPackage
ogr2ogr-f GPKG -a_srs EPSG:3844 ro_frontiera_polilinie.gpkg ro_frontiera_polilinie.shp

#creare versiune GeoJSON
ogr2ogr-f GeoJSON -s_srs EPSG:3844 -t_srs EPSG:4326 ro_frontiera_polilinie.geojson ro_frontiera_polilinie.shp

#creare versiune KML
ogr2ogr-f KML -s_srs EPSG:3844 -t_srs EPSG:4326 -dsco NameField=name ro_frontiera_polilinie.kml ro_frontiera_polilinie.shp

#copiere fișiere în directorul de download
cp -rf ro_frontiera_polilinie.zip ro_frontiera_polilinie.gpkg ro_frontiera_polilinie.geojson ro_frontiera_polilinie.kml /var/www/geospatial/files/vector/limite_administrative/frontiera

#actualizarea setului de date în baza de date PostGIS
ogr2ogr-f "PostgreSQL" PG:"host=localhost user=username dbname=geospatial password=password" -lco schema=romania -lco overwrite=yes ro_frontiera_polilinie.shp ro_frontiera_polilinie -a_srs EPSG:3844 -skipfailures -overwrite

#actualizarea metadatelor din serviciile de date
curl -u username:password -XPUT -H "Content-type: text/xml" -d "<featureType><abstract>Setul de date cuprinde granița României (geometrie polilinie). Actualizare 23.03.2016. Sursa ANCPI.</abstract><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/geospatial/datastores/geospatial_romania/featuretypes/ro_frontiera_polilinie

rm ro_frontiera*.*
