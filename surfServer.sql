/*
 Navicat Premium Data Transfer

 Source Server         : Centurio
 Source Server Type    : MySQL
 Source Server Version : 50171
 Source Host           : localhost
 Source Database       : surfOne

 Target Server Type    : MySQL
 Target Server Version : 50171
 File Encoding         : utf-8

 Date: 12/24/2013 12:11:40 PM
*/

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
--  Table structure for `custom_chatcolors`
-- ----------------------------
DROP TABLE IF EXISTS `custom_chatcolors`;
CREATE TABLE `custom_chatcolors` (
  `index` int(11) NOT NULL,
  `identity` varchar(32) NOT NULL,
  `flag` char(1) DEFAULT NULL,
  `tag` varchar(32) DEFAULT NULL,
  `tagcolor` varchar(8) DEFAULT NULL,
  `namecolor` varchar(8) DEFAULT NULL,
  `textcolor` varchar(8) DEFAULT NULL,
  `comment` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`index`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- ----------------------------
--  Table structure for `invited_players`
-- ----------------------------
DROP TABLE IF EXISTS `invited_players`;
CREATE TABLE `invited_players` (
  `invite_id` int(11) NOT NULL AUTO_INCREMENT,
  `communityid` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`invite_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- ----------------------------
--  Table structure for `map_zones`
-- ----------------------------
DROP TABLE IF EXISTS `map_zones`;
CREATE TABLE `map_zones` (
  `map_zone_id` int(11) NOT NULL AUTO_INCREMENT,
  `map_id` int(11) NOT NULL,
  `map_zone_type` int(11) NOT NULL,
  `map_zone_checkpoint_order_id` int(11) NOT NULL,
  `map_zone_point1_x` float NOT NULL,
  `map_zone_point1_y` float NOT NULL,
  `map_zone_point1_z` float NOT NULL,
  `map_zone_point2_x` float NOT NULL,
  `map_zone_point2_y` float NOT NULL,
  `map_zone_point2_z` float NOT NULL,
  `map_zone_respawn_position` int(11) DEFAULT '0',
  PRIMARY KEY (`map_zone_id`),
  KEY `idx_maps_id` (`map_id`),
  KEY `idx_type` (`map_zone_type`),
  KEY `idx_order_id` (`map_zone_checkpoint_order_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1502 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ----------------------------
--  Table structure for `maps`
-- ----------------------------
DROP TABLE IF EXISTS `maps`;
CREATE TABLE `maps` (
  `map_id` int(11) NOT NULL AUTO_INCREMENT,
  `map_name` varchar(64) CHARACTER SET utf8 NOT NULL,
  `map_type` tinyint(4) DEFAULT '0',
  `map_difficulty` tinyint(1) DEFAULT '0',
  `map_enabled` tinyint(4) DEFAULT '0',
  `map_last_played` int(11) NOT NULL DEFAULT '0',
  `map_times_played` int(11) NOT NULL DEFAULT '0',
  `map_total_completitions` int(11) NOT NULL DEFAULT '0',
  `map_total_bonus_completitions` int(11) NOT NULL DEFAULT '0',
  `map_total_wrs` int(11) NOT NULL DEFAULT '0',
  `map_bonus_total_wrs` int(11) NOT NULL DEFAULT '0',
  `map_bonus_type` tinyint(4) NOT NULL DEFAULT '0',
  `map_creator_id` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`map_id`),
  UNIQUE KEY `idx_map_name` (`map_name`)
) ENGINE=MyISAM AUTO_INCREMENT=331 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
--  Table structure for `user`
-- ----------------------------
DROP TABLE IF EXISTS `user`;
CREATE TABLE `user` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_steam_id` varchar(255) CHARACTER SET utf8 NOT NULL,
  `user_name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `user_first_connect` int(11) DEFAULT '0',
  `user_last_connect` int(11) DEFAULT '0',
  `user_connect_count` int(11) DEFAULT '0',
  `user_points` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `idx_user_steam_id` (`user_steam_id`),
  KEY `idx_user_points` (`user_points`)
) ENGINE=MyISAM AUTO_INCREMENT=2570 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ----------------------------
--  Table structure for `user_names`
-- ----------------------------
DROP TABLE IF EXISTS `user_names`;
CREATE TABLE `user_names` (
  `user_name_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `user_name` varchar(255) CHARACTER SET utf8 NOT NULL,
  PRIMARY KEY (`user_name_id`),
  UNIQUE KEY `unq_user_id_user_name` (`user_id`,`user_name`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=MyISAM AUTO_INCREMENT=2996 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ----------------------------
--  Table structure for `user_records`
-- ----------------------------
DROP TABLE IF EXISTS `user_records`;
CREATE TABLE `user_records` (
  `user_records_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_user_id` int(11) NOT NULL,
  `maps_map_id` int(11) NOT NULL,
  `user_record_time` double NOT NULL,
  `user_record_created_at` int(11) NOT NULL,
  `user_record_points` int(11) NOT NULL DEFAULT '0',
  `user_record_was_wr` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_records_id`),
  KEY `idx_user_id` (`user_user_id`),
  KEY `idx_maps_id` (`maps_map_id`),
  KEY `idx_record_time` (`user_record_time`) USING BTREE,
  KEY `idx_record_points` (`user_record_points`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=9715 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ----------------------------
--  Table structure for `user_stage_records`
-- ----------------------------
DROP TABLE IF EXISTS `user_stage_records`;
CREATE TABLE `user_stage_records` (
  `user_stage_records_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_user_id` int(11) NOT NULL,
  `maps_map_id` int(11) NOT NULL,
  `user_stage_records_stage_id` int(11) NOT NULL,
  `user_stage_records_time` double NOT NULL,
  `user_stage_records_created_at` int(11) NOT NULL,
  `user_stage_record_is_wr` tinyint(4) NOT NULL DEFAULT '0',
  `user_stage_record_points` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_stage_records_id`),
  KEY `idx_user_id` (`user_user_id`),
  KEY `idx_maps_id` (`maps_map_id`),
  KEY `idx_stage_id` (`user_stage_records_stage_id`),
  KEY `idx_times` (`user_stage_records_time`)
) ENGINE=MyISAM AUTO_INCREMENT=29866 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
