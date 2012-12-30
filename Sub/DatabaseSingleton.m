//
//  DatabaseSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "ISMSQueueAllLoader.h"
#import "PlaylistSingleton.h"
#import "ISMSStreamManager.h"
#import "JukeboxSingleton.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation DatabaseSingleton

#pragma mark -
#pragma mark class instance methods

- (void)setupAllSongsDb
{
	NSString *urlStringMd5 = [[settingsS urlString] md5];
	
	// Setup the allAlbums database
	NSString *path = [NSString stringWithFormat:@"%@/%@allAlbums.db", self.databaseFolderPath, urlStringMd5];
	self.allAlbumsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allAlbumsDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the allSongs database
	path = [NSString stringWithFormat:@"%@/%@allSongs.db", self.databaseFolderPath, urlStringMd5];
	self.allSongsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allSongsDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the Genres database
	path = [NSString stringWithFormat:@"%@/%@genres.db", self.databaseFolderPath, urlStringMd5];
	self.genresDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.genresDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
}

- (void)setupDatabases
{
	NSString *urlStringMd5 = [[settingsS urlString] md5];
    DDLogVerbose(@"Database prefix: %@", urlStringMd5);
		
	// Only load Albums, Songs, and Genre databases if this is a newer device
	if (settingsS.isSongsTabEnabled)
	{
		[self setupAllSongsDb];
	}
	
	// Setup the album list cache database
	NSString *path = [NSString stringWithFormat:@"%@/%@albumListCache.db", self.databaseFolderPath, urlStringMd5];
	self.albumListCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"albumListCache"]) 
		{
			[db executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
		if (![db tableExists:@"albumsCache"]) 
		{
			[db executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		}
		if (![db tableExists:@"songsCache"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		}
        if (![db tableExists:@"albumsCacheCount"])
        {
            [db executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
            [db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
        }
        if (![db tableExists:@"songsCacheCount"])
        {
            [db executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
            [db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
        }
        if (![db tableExists:@"folderLength"])
        {
            [db executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
            [db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
        }
	}];
	
	// Setup music player cover art cache database
	if (IS_IPAD())
	{
		// Only load large album art DB if this is an iPad
		path = [NSString stringWithFormat:@"%@/coverArtCache540.db", self.databaseFolderPath];
		self.coverArtCacheDb540Queue = [FMDatabaseQueue databaseQueueWithPath:path];
		[self.coverArtCacheDb540Queue inDatabase:^(FMDatabase *db) 
		{
			[db executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![db tableExists:@"coverArtCache"]) 
			{
				[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}];
	}
	else
	{
		// Only load small album art DB if this is not an iPad
		path = [NSString stringWithFormat:@"%@/coverArtCache320.db", self.databaseFolderPath];
		self.coverArtCacheDb320Queue = [FMDatabaseQueue databaseQueueWithPath:path];
		[self.coverArtCacheDb320Queue inDatabase:^(FMDatabase *db) 
		{
			[db executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![db tableExists:@"coverArtCache"]) 
			{
				[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}];
	}
	
	// Setup album cell cover art cache database
	path = [NSString stringWithFormat:@"%@/coverArtCache60.db", self.databaseFolderPath];
	self.coverArtCacheDb60Queue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.coverArtCacheDb60Queue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"coverArtCache"])
		{
			[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}];
	
	// Setup the current playlist database
	if (settingsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/offlineCurrentPlaylist.db", self.databaseFolderPath];
	}
	else 
	{
		path = [NSString stringWithFormat:@"%@/%@currentPlaylist.db", self.databaseFolderPath, urlStringMd5];		
	}
	
	self.currentPlaylistDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"currentPlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
		if (![db tableExists:@"shufflePlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
		if (![db tableExists:@"jukeboxCurrentPlaylist"])
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
		if (![db tableExists:@"jukeboxShufflePlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
	}];	
	
	// Setup the local playlists database
	if (settingsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/offlineLocalPlaylists.db", self.databaseFolderPath];
	}
	else 
	{
		path = [NSString stringWithFormat:@"%@/%@localPlaylists.db", self.databaseFolderPath, urlStringMd5];
	}
	
	self.localPlaylistsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"localPlaylists"]) 
		{
			[db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
		}
	}];
    
    // Handle moving the song cache database if necessary
    path = [[settingsS.currentCacheRoot stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    if (![defaultManager fileExistsAtPath:path])
    {
        // First check to see if it's in the old Library/Caches location
        NSString *oldPath = [settingsS.cachesPath stringByAppendingPathComponent:@"songCache.db"];
        if ([defaultManager fileExistsAtPath:oldPath])
        {
            // It exists there, so move it to the new location
            NSError *error;
            [defaultManager moveItemAtPath:oldPath toPath:path error:&error];
            
            if (error)
            {
                DDLogError(@"Error moving cache path from %@ to %@", oldPath, path);
            }
            else
            {
                DDLogInfo(@"Moved cache path from %@ to %@", oldPath, path);
                
                // Now set the file not to be backed up
                [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
            }
        }
    }
	
	self.songCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"cachedSongs"])
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX cachedDate ON cachedSongs (cachedDate DESC)"];
			[db executeUpdate:@"CREATE INDEX playedDate ON cachedSongs (playedDate DESC)"];
		}
		[db executeUpdate:@"CREATE INDEX md5 IF NOT EXISTS ON cachedSongs (md5)"];
		if (![db tableExists:@"cachedSongsLayout"]) 
		{
			[db executeUpdate:@"CREATE TABLE cachedSongsLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			[db executeUpdate:@"CREATE INDEX genreLayout ON cachedSongsLayout (genre)"];
			[db executeUpdate:@"CREATE INDEX seg1 ON cachedSongsLayout (seg1)"];
			[db executeUpdate:@"CREATE INDEX seg2 ON cachedSongsLayout (seg2)"];
			[db executeUpdate:@"CREATE INDEX seg3 ON cachedSongsLayout (seg3)"];
			[db executeUpdate:@"CREATE INDEX seg4 ON cachedSongsLayout (seg4)"];
			[db executeUpdate:@"CREATE INDEX seg5 ON cachedSongsLayout (seg5)"];
			[db executeUpdate:@"CREATE INDEX seg6 ON cachedSongsLayout (seg6)"];
			[db executeUpdate:@"CREATE INDEX seg7 ON cachedSongsLayout (seg7)"];
			[db executeUpdate:@"CREATE INDEX seg8 ON cachedSongsLayout (seg8)"];
			[db executeUpdate:@"CREATE INDEX seg9 ON cachedSongsLayout (seg9)"];
		}
		DLog(@"checking if genres table exists");
		if (![db tableExists:@"genres"]) 
		{
			DLog(@"doesn't exist, creating genres table");
			[db executeUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
		}
		if (![db tableExists:@"genresSongs"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, %@)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songGenre ON genresSongs (genre)"];
		}
	}];
	
	// Handle moving the song cache database if necessary
	path = [NSString stringWithFormat:@"%@/database/%@cacheQueue.db", settingsS.currentCacheRoot, settingsS.urlString.md5];
    if (![defaultManager fileExistsAtPath:path])
    {
        // First check to see if it's in the old Library/Caches location
        NSString *oldPath = [NSString stringWithFormat:@"%@/%@cacheQueue.db", settingsS.cachesPath, settingsS.urlString.md5];
        if ([defaultManager fileExistsAtPath:oldPath])
        {
            // It exists there, so move it to the new location
            NSError *error;
            [defaultManager moveItemAtPath:oldPath toPath:path error:&error];
            
            if (error)
            {
                DDLogError(@"Error moving cache path from %@ to %@", oldPath, path);
            }
            else
            {
                DDLogInfo(@"Moved cache path from %@ to %@", oldPath, path);
                
                // Now set the file not to be backed up
                [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
            }
        }
    }
	
	self.cacheQueueDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"cacheQueue"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [ISMSSong standardSongColumnSchema]]];
			//[cacheQueueDb executeUpdate:@"CREATE INDEX queueDate ON cacheQueue (cachedDate DESC)"];
		}
	}];
		
	// Setup the lyrics database
	path = [NSString stringWithFormat:@"%@/lyrics.db", self.databaseFolderPath];
	self.lyricsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.lyricsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"lyrics"])
		{
			[db executeUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
			[db executeUpdate:@"CREATE INDEX artistTitle ON lyrics (artist, title)"];
		}
	}];
	
	// Setup the bookmarks database
	if (settingsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/bookmarks.db", self.databaseFolderPath];
	}
	else
	{
		path = [NSString stringWithFormat:@"%@/%@bookmarks.db", self.databaseFolderPath, urlStringMd5];
	}
	
	self.bookmarksDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if ([db tableExists:@"bookmarks"])
        {
            // Make sure the isVideo column is there
            if (![db columnExists:@"isVideo" inTableWithName:@"bookmarks"])
            {
                // Doesn't exist so fix the table definition
                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
                [db executeUpdate:@"INSERT INTO bookmarksTemp SELECT bookmarkId, playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId, 0, bytes FROM bookmarks"];
                [db executeUpdate:@"DROP TABLE bookmarks"];
                [db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
                [db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
            }
        }
        else
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}];
	
	[self updateTableDefinitions];
}

- (void)updateTableDefinitions
{
	// Add parentId column to tables if necessary
	NSArray *parentIdDatabaseQueues = @[self.albumListCacheDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.songCacheDbQueue, self.songCacheDbQueue, self.cacheQueueDbQueue, self.songCacheDbQueue, self.cacheQueueDbQueue];
	NSArray *parentIdTables = @[@"songsCache", @"currentPlaylist", @"shufflePlaylist", @"jukeboxCurrentPlaylist", @"jukeboxShufflePlaylist", @"cachedSongs", @"genresSongs", @"cacheQueue", @"cachedSongsList", @"queuedSongsList"];
	NSString *parentIdColumnName = @"parentId";
    NSString *isVideoColumnName = @"isVideo";
	for (int i = 0; i < [parentIdDatabaseQueues count]; i++)
	{
		FMDatabaseQueue *dbQueue = [parentIdDatabaseQueues objectAtIndexSafe:i];
		NSString *table = [parentIdTables objectAtIndexSafe:i];
		
		[dbQueue inDatabase:^(FMDatabase *db)
		{
			if (![db columnExists:parentIdColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, parentIdColumnName];
				[db executeUpdate:query];
			}
            
            if (![db columnExists:isVideoColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, isVideoColumnName];
				[db executeUpdate:query];
			}
		}];
	}
	
	// Add parentId to all playlist and splaylist tables
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
		NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *tableName = [result stringForColumnIndex:0];
				if ([tableName length] > 8)
				{
					NSString *tableNameSubstring = [tableName substringToIndex:8];
					if ([tableNameSubstring isEqualToString:@"playlist"] ||
						[tableNameSubstring isEqualToString:@"splaylis"])
					{
						[playlistTableNames addObject:tableName];
					}
				}
			}
		}
		[result close];
		
		for (NSString *table in playlistTableNames)
		{
			if (![db columnExists:parentIdColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, parentIdColumnName];
				[db executeUpdate:query];
			}
            
            if (![db columnExists:isVideoColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, isVideoColumnName];
				[db executeUpdate:query];
			}
		}
	}];
	
	// Update the bookmarks table to new format
	[self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		if (![db columnExists:@"bookmarkId" inTableWithName:@"bookmarks"])
		{
			// Create the new table
			[db executeUpdate:@"DROP TABLE IF EXISTS bookmarksTemp"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
			
			// Move the records
			[db executeUpdate:@"INSERT INTO bookmarksTemp (playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) SELECT 0, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size FROM bookmarks"];
			
			// Swap the tables
			[db executeUpdate:@"DROP TABLE IF EXISTS bookmarks"];
			[db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];	
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}];
	
	[self.songCacheDbQueue inDatabase:^(FMDatabase *db)
	 {
		 if (![db tableExists:@"genresTableFixed"])
		 {
			 [db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			 [db executeUpdate:@"CREATE TABLE genresTemp (genre TEXT)"];
			 [db executeUpdate:@"INSERT INTO genresTemp SELECT * FROM genres"];
			 [db executeUpdate:@"DROP TABLE genres"];
			 [db executeUpdate:@"ALTER TABLE genresTemp RENAME TO genres"];
			 [db executeUpdate:@"CREATE UNIQUE INDEX genreNames ON genres (genre)"];
			 [db executeUpdate:@"CREATE TABLE genresTableFixed (a INTEGER)"];
		 }
	 }];
}

- (void)closeAllDatabases
{
	[self.allAlbumsDbQueue close]; self.allAlbumsDbQueue = nil;
	[self.allSongsDbQueue close]; self.allSongsDbQueue = nil;
	[self.genresDbQueue close]; self.genresDbQueue = nil;
	[self.albumListCacheDbQueue close]; self.albumListCacheDbQueue = nil;
	[self.coverArtCacheDb540Queue close]; self.coverArtCacheDb540Queue = nil;
	[self.coverArtCacheDb320Queue close]; self.coverArtCacheDb320Queue = nil;
	[self.coverArtCacheDb60Queue close]; self.coverArtCacheDb60Queue = nil;
	[self.currentPlaylistDbQueue close]; self.currentPlaylistDbQueue = nil;
	[self.localPlaylistsDbQueue close]; self.localPlaylistsDbQueue = nil;
	[self.songCacheDbQueue close]; self.songCacheDbQueue = nil;
	[self.cacheQueueDbQueue close]; self.cacheQueueDbQueue = nil;
	[self.bookmarksDbQueue close]; self.bookmarksDbQueue = nil;	
}

- (void)resetCoverArtCache
{	
	// Clear the table cell cover art	
	[self.coverArtCacheDb60Queue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS coverArtCache"];
		[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}];
	
	
	// Clear the player cover art
	FMDatabaseQueue *dbQueue = IS_IPAD() ? self.coverArtCacheDb540Queue : self.coverArtCacheDb320Queue;
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS coverArtCache"];
		[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}];
}

- (void)resetFolderCache
{	
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		// Drop the tables
		[db executeUpdate:@"DROP TABLE albumListCache"];
		[db executeUpdate:@"DROP TABLE albumsCache"];
		[db executeUpdate:@"DROP TABLE albumsCacheCount"];
		[db executeUpdate:@"DROP TABLE songsCacheCount"];
		[db executeUpdate:@"DROP TABLE folderLength"];
		
		// Create the tables and indexes
		[db executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		[db executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
		[db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
		[db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		[db executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
		[db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
	}];
}

- (void)resetLocalPlaylistsDb
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		// Get the table names
		NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
		NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *tableName = [result stringForColumnIndex:0];
				[playlistTableNames addObject:tableName];
			}
		}
		[result close];
		
		// Drop the tables
		for (NSString *table in playlistTableNames)
		{
			NSString *query = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", table];
			[db executeUpdate:query];
		} 
		
		// Create the localPlaylists table
		[db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}];
}

- (void)resetCurrentPlaylistDb
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		// Drop the tables
		[db executeUpdate:@"DROP TABLE IF EXISTS currentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS shufflePlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxCurrentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxShufflePlaylist"];
		
		// Create the tables
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
	}];	
}

- (void)resetCurrentPlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE currentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
	}];
}

- (void)resetShufflePlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE shufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
	}];
}

- (void)resetJukeboxPlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		
		[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
	}];
}

- (void)createServerPlaylistTable:(NSString *)md5
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE splaylist%@ (%@)", md5, [ISMSSong standardSongColumnSchema]]];
	}];	
}

- (void)removeServerPlaylistTable:(NSString *)md5
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", md5]];
	}];
}

- (ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block ISMSAlbum *anAlbum = nil;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		anAlbum = [self albumFromDbRow:row inTable:table inDatabase:db];
	}];
	
	return anAlbum;
}

- (ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	row++;
	ISMSAlbum *anAlbum = nil;
	
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %lu", table, (unsigned long)row]];
	if ([db hadError]) 
	{
	//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	else
	{
		if ([result next])
		{
			anAlbum = [[ISMSAlbum alloc] init];

			if ([result stringForColumn:@"title"] != nil)
				anAlbum.title = [NSString stringWithString:[result stringForColumn:@"title"]];
			if ([result stringForColumn:@"albumId"] != nil)
				anAlbum.albumId = [NSString stringWithString:[result stringForColumn:@"albumId"]];
			if ([result stringForColumn:@"coverArtId"] != nil)
				anAlbum.coverArtId = [NSString stringWithString:[result stringForColumn:@"coverArtId"]];
			if ([result stringForColumn:@"artistName"] != nil)
				anAlbum.artistName = [NSString stringWithString:[result stringForColumn:@"artistName"]];
			if ([result stringForColumn:@"artistId"] != nil)
				anAlbum.artistId = [NSString stringWithString:[result stringForColumn:@"artistId"]];
		}
	}
	[result close];
	
	return anAlbum;
}

- (NSUInteger)serverPlaylistCount:(NSString *)md5
{
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%@", md5];
	return [self.localPlaylistsDbQueue intForQuery:query];
}

- (BOOL)insertAlbumIntoFolderCache:(ISMSAlbum *)anAlbum forId:(NSString *)folderId
{
	__block BOOL hadError;
	
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", [folderId md5], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
		
		hadError = [db hadError];
		
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertAlbum:(ISMSAlbum *)anAlbum intoTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block BOOL success;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		success = [self insertAlbum:anAlbum intoTable:table inDatabase:db];
	}];
	
	return success;
}

- (BOOL)insertAlbum:(ISMSAlbum *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?)", table], anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([db hadError]) {
	//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column
{
	__block NSArray *sectionInfo;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		sectionInfo = [self sectionInfoFromTable:table inDatabase:db withColumn:column];
	}];
	
	return sectionInfo;
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column
{	
	NSArray *sectionTitles = [[NSArray alloc] initWithObjects:@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
	int i = 0;
	for (NSString *title in sectionTitles)
	{
        NSArray *articles = [NSString indefiniteArticles];
        
        NSString *section = [sectionTitles objectAtIndexSafe:i];
        NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT ROWID FROM %@ WHERE %@ LIKE '%@%%'", table, column, section];
        for (NSString *article in articles)
        {
            [query appendFormat:@"AND %@ NOT LIKE '%@ %%' ", column, article];
        }
        [query appendString:@"LIMIT 1"];

		NSString *row = [database stringForQuery:query];
		if (row != nil)
		{
			[sections addObject:[NSArray arrayWithObjects:[sectionTitles objectAtIndexSafe:i], @([row intValue] - 1), nil]];
		}
		
		i++;
	}
	
	if ([sections count] > 0)
	{
		if ([[[sections objectAtIndexSafe:0] objectAtIndexSafe:1] intValue] > 0)
		{
			[sections insertObject:[NSArray arrayWithObjects:@"#", @0, nil] atIndex:0];
		}
	}
	else
	{
		// Looks like there are only number rows, make sure the table is not empty
		NSString *row = [database stringForQuery:[NSString stringWithFormat:@"SELECT ROWID FROM %@ LIMIT 1", table]];
		if (row)
		{
			[sections insertObject:[NSArray arrayWithObjects:@"#", @0, nil] atIndex:0];
		}
	}
	
	NSArray *returnArray = [NSArray arrayWithArray:sections];
	
	return returnArray;
}


- (void)downloadAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Download all the songs
	[self.queueAll cacheData:folderId artist:theArtist];
}

- (void)queueAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Queue all the songs
	[self.queueAll queueData:folderId artist:theArtist];
}

/*- (void)queueSong:(ISMSSong *)aSong
{
	if (settingsS.isJukeboxEnabled)
	{
		[aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
		[jukeboxS jukeboxAddSong:aSong.songId];
	}
	else
	{
		[aSong insertIntoTable:@"currentPlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
		if (playlistS.isShuffle)
			[aSong insertIntoTable:@"shufflePlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
	}
	
	[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
}*/

- (void)playAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Set shuffle off in case it's on
	playlistS.isShuffle = NO;
	
	// Queue all the songs
	[self.queueAll playAllData:folderId artist:theArtist];
}

- (void)shuffleAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}

	// Set shuffle on
	playlistS.isShuffle = YES;
	
	// Queue all the songs
	[self.queueAll shuffleData:folderId artist:theArtist];
}

- (void)shufflePlaylist
{
	@autoreleasepool 
	{
		playlistS.currentIndex = 0;
		playlistS.isShuffle = YES;
		
		[self resetShufflePlaylist];
		
		[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
		{
			if (settingsS.isJukeboxEnabled)
				[db executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist ORDER BY RANDOM()"];
			else
				[db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		}];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
	}
}

// New Model Stuff


#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup 
{
	_queueAll = [ISMSQueueAllLoader loader];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	_databaseFolderPath = [[paths objectAtIndexSafe: 0] stringByAppendingPathComponent:@"database"];
	
	// Make sure database directory exists, if not create them
	BOOL isDir = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:_databaseFolderPath isDirectory:&isDir])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:_databaseFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}	
	
	[self setupDatabases];
	
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (id)sharedInstance
{
    static DatabaseSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
