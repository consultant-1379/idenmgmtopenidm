-- -----------------------------------
--    Default SQL settings for openIDM
--           Ericsson
--
-- -----------------------------------



SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

CREATE SCHEMA IF NOT EXISTS `openidm` DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_bin;
USE `openidm` ;

-- -----------------------------------------------------
-- Table `openidm`.`objecttypes`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`objecttypes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `objecttype` VARCHAR(255) NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `idx_objecttypes_objecttype` (`objecttype` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`genericobjects`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`genericobjects` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `objecttypes_id` BIGINT UNSIGNED NOT NULL ,
  `objectid` VARCHAR(255) NOT NULL ,
  `rev` VARCHAR(38) NOT NULL ,
  `fullobject` MEDIUMTEXT NULL ,
  INDEX `fk_genericobjects_objecttypes` (`objecttypes_id` ASC) ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `idx_genericobjects_object` (`objecttypes_id` ASC, `objectid` ASC) ,
  CONSTRAINT `fk_genericobjects_objecttypes`
    FOREIGN KEY (`objecttypes_id` )
    REFERENCES `openidm`.`objecttypes` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`genericobjectproperties`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`genericobjectproperties` (
  `genericobjects_id` BIGINT UNSIGNED NOT NULL ,
  `propkey` VARCHAR(255) NOT NULL ,
  `proptype` VARCHAR(32) NULL ,
  `propvalue` TEXT NULL ,
  INDEX `fk_genericobjectproperties_genericobjects` (`genericobjects_id` ASC) ,
  INDEX `idx_genericobjectproperties_prop` (`propkey` ASC, `propvalue`(23) ASC) ,
  CONSTRAINT `fk_genericobjectproperties_genericobjects`
    FOREIGN KEY (`genericobjects_id` )
    REFERENCES `openidm`.`genericobjects` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`managedobjects`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`managedobjects` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `objecttypes_id` BIGINT UNSIGNED NOT NULL ,
  `objectid` VARCHAR(255) NOT NULL ,
  `rev` VARCHAR(38) NOT NULL ,
  `fullobject` MEDIUMTEXT NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `idx-managedobjects_object` (`objecttypes_id` ASC, `objectid` ASC) ,
  INDEX `fk_managedobjects_objectypes` (`objecttypes_id` ASC) ,
  CONSTRAINT `fk_managedobjects_objectypes`
    FOREIGN KEY (`objecttypes_id` )
    REFERENCES `openidm`.`objecttypes` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`managedobjectproperties`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`managedobjectproperties` (
  `managedobjects_id` BIGINT UNSIGNED NOT NULL ,
  `propkey` VARCHAR(255) NOT NULL ,
  `proptype` VARCHAR(32) NULL ,
  `propvalue` TEXT NULL ,
  INDEX `fk_managedobjectproperties_managedobjects` (`managedobjects_id` ASC) ,
  INDEX `idx_managedobjectproperties_prop` (`propkey` ASC, `propvalue`(23) ASC) ,
  CONSTRAINT `fk_managedobjectproperties_managedobjects`
    FOREIGN KEY (`managedobjects_id` )
    REFERENCES `openidm`.`managedobjects` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`configobjects`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`configobjects` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `objecttypes_id` BIGINT UNSIGNED NOT NULL ,
  `objectid` VARCHAR(255) NOT NULL ,
  `rev` VARCHAR(38) NOT NULL ,
  `fullobject` MEDIUMTEXT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_configobjects_objecttypes` (`objecttypes_id` ASC) ,
  UNIQUE INDEX `idx_configobjects_object` (`objecttypes_id` ASC, `objectid` ASC) ,
  CONSTRAINT `fk_configobjects_objecttypes`
    FOREIGN KEY (`objecttypes_id` )
    REFERENCES `openidm`.`objecttypes` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`configobjectproperties`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`configobjectproperties` (
  `configobjects_id` BIGINT UNSIGNED NOT NULL ,
  `propkey` VARCHAR(255) NOT NULL ,
  `proptype` VARCHAR(32) NULL ,
  `propvalue` TEXT NULL ,
  INDEX `fk_configobjectproperties_configobjects` (`configobjects_id` ASC) ,
  INDEX `idx_configobjectproperties_prop` (`propkey` ASC, `propvalue`(23) ASC) ,
  CONSTRAINT `fk_configobjectproperties_configobjects`
    FOREIGN KEY (`configobjects_id` )
    REFERENCES `openidm`.`configobjects` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`links`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`links` (
  `objectid` VARCHAR(38) NOT NULL ,
  `rev` VARCHAR(38) NOT NULL ,
  `linktype` VARCHAR(255) NOT NULL ,
  `firstid` VARCHAR(255) NOT NULL ,
  `secondid` VARCHAR(255) NOT NULL ,
  UNIQUE INDEX `idx_links_first` (`linktype` ASC, `firstid` ASC) ,
  UNIQUE INDEX `idx_links_second` (`linktype` ASC, `secondid` ASC) ,
  PRIMARY KEY (`objectid`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`auditrecon`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`auditrecon` (
  `objectid` VARCHAR(38) NOT NULL ,
  `entrytype` VARCHAR(7) NULL ,
  `rootactionid` VARCHAR(511) NULL ,
  `reconid` VARCHAR(36) NULL ,
  `reconciling` VARCHAR(12) NULL ,
  `sourceobjectid` VARCHAR(511) NULL ,
  `targetobjectid` VARCHAR(511) NULL ,
  `ambiguoustargetobjectids` MEDIUMTEXT NULL ,
  `activitydate` VARCHAR(29) NULL COMMENT 'Date format: 2011-09-09T14:58:17.654+02:00' ,
  `situation` VARCHAR(24) NULL ,
  `activity` VARCHAR(24) NULL ,
  `status` VARCHAR(7) NULL ,
  `message` TEXT NULL ,
  PRIMARY KEY (`objectid`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`auditactivity`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`auditactivity` (
  `objectid` VARCHAR(38) NOT NULL ,
  `rootactionid` VARCHAR(511) NULL ,
  `parentactionid` VARCHAR(511) NULL ,
  `activityid` VARCHAR(511) NULL ,
  `activitydate` VARCHAR(29) NULL COMMENT 'Date format: 2011-09-09T14:58:17.654+02:00' ,
  `activity` VARCHAR(24) NULL ,
  `message` TEXT NULL ,
  `subjectid` VARCHAR(511) NULL ,
  `subjectrev` VARCHAR(38) NULL ,
  `requester` TEXT NULL ,
  `approver` TEXT NULL ,
  `subjectbefore` MEDIUMTEXT NULL ,
  `subjectafter` MEDIUMTEXT NULL ,
  `status` VARCHAR(7) NULL ,
  `changedfields` VARCHAR(255) NULL ,
  `passwordchanged` VARCHAR(5) NULL ,
  PRIMARY KEY (`objectid`) ,
  INDEX `idx_auditactivity_rootactionid` (`rootactionid` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`internaluser`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`internaluser` (
  `objectid` VARCHAR(254) NOT NULL ,
  `rev` VARCHAR(38) NOT NULL ,
  `pwd` VARCHAR(510) NULL ,
  `roles` VARCHAR(1024) NULL ,
  PRIMARY KEY (`objectid`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`auditaccess`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`auditaccess` (
  `objectid` VARCHAR(38) NOT NULL ,
  `activitydate` VARCHAR(29) NULL COMMENT 'Date format: 2011-09-09T14:58:17.654+02:00' ,
  `activity` VARCHAR(24) NULL ,
  `ip` VARCHAR(40) NULL ,
  `principal` TEXT NULL ,
  `roles` VARCHAR(1024) NULL ,
  `status` VARCHAR(7) NULL ,
  PRIMARY KEY (`objectid`) )
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `openidm`.`schedulerobjects`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`schedulerobjects` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `objecttypes_id` BIGINT UNSIGNED NOT NULL ,
  `objectid` VARCHAR(255) NOT NULL ,
  `rev` VARCHAR(38) NOT NULL ,
  `fullobject` MEDIUMTEXT NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `idx-schedulerobjects_object` (`objecttypes_id` ASC, `objectid` ASC) ,
  INDEX `fk_schedulerobjects_objectypes` (`objecttypes_id` ASC) ,
  CONSTRAINT `fk_schedulerobjects_objectypes`
    FOREIGN KEY (`objecttypes_id` )
    REFERENCES `openidm`.`objecttypes` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`schedulerobjectproperties`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`schedulerobjectproperties` (
  `schedulerobjects_id` BIGINT UNSIGNED NOT NULL ,
  `propkey` VARCHAR(255) NOT NULL ,
  `proptype` VARCHAR(32) NULL ,
  `propvalue` TEXT NULL ,
  INDEX `fk_schedulerobjectproperties_schedulerobjects` (`schedulerobjects_id` ASC) ,
  INDEX `idx_schedulerobjectproperties_prop` (`propkey` ASC, `propvalue`(23) ASC) ,
  CONSTRAINT `fk_schedulerobjectproperties_schedulerobjects`
    FOREIGN KEY (`schedulerobjects_id` )
    REFERENCES `openidm`.`schedulerobjects` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `openidm`.`uinotification`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `openidm`.`uinotification` (
  `objectid` VARCHAR(38) NOT NULL ,
  `rev` VARCHAR(38) NOT NULL ,
  `notificationType` VARCHAR(255) NOT NULL ,
  `createDate` VARCHAR(255) NOT NULL ,
  `message` TEXT NOT NULL ,
  `requester` VARCHAR(255) NULL ,
  `receiverId` VARCHAR(38) NOT NULL ,
  `requesterId` VARCHAR(38) NULL ,
  `notificationSubtype` VARCHAR(255) NULL ,
  PRIMARY KEY (`objectid`) )
ENGINE = InnoDB;



SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
-- Data for table `openidm`.`internaluser`
-- -----------------------------------------------------
START TRANSACTION;
USE `openidm`;
INSERT INTO `openidm`.`internaluser` (`objectid`, `rev`, `pwd`, `roles`) VALUES ('openidm-admin', '0', '{\"$crypto\":{\"value\":{\"iv\":\"fIevcJYS4TMxClqcK7covg==\",\"data\":\"Tu9o/S+j+rhOIgdp9uYc5Q==\",\"cipher\":\"AES/CBC/PKCS5Padding\",\"key\":\"openidm-sym-default\"},\"type\":\"x-simple-encryption\"}}', 'openidm-admin,openidm-authorized');
INSERT INTO `openidm`.`internaluser` (`objectid`, `rev`, `pwd`, `roles`) VALUES ('anonymous', '0', 'anonymous', 'openidm-reg');

COMMIT;

-- -------------------------------------------
-- openidm database user
-- ------------------------------------------
GRANT ALL PRIVILEGES on openidm.* TO openidm IDENTIFIED BY 'openidm';
GRANT ALL PRIVILEGES on openidm.* TO openidm@'%' IDENTIFIED BY 'openidm';
GRANT ALL PRIVILEGES on openidm.* TO openidm@localhost IDENTIFIED BY 'openidm';
