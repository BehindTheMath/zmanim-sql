DELIMITER ;;

# JewishDate.getLastDayOfGregorianMonth()
/**
 * Returns the number of days in a given month in a given month and year.
 *
 * @param month
 *            the month. As with other cases in this class, this is 1-based, not zero-based.
 * @param year
 *            the year (only impacts February)
 * @return the number of days in the month in the given year
 */
CREATE FUNCTION JewishDate_getLastDayOfGregorianMonth(month INTEGER UNSIGNED, year INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    RETURN (
        CASE
            WHEN month = 2 THEN IF((year % 4 = 0 AND year % 100 != 0) OR (year % 400 = 0), 29, 28)
            WHEN month IN (4, 6, 9, 11) THEN 30
            ELSE 31
            END);

END ;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.gregorianDateToAbsDate()
/**
 * Computes the absolute date from a Gregorian date. ND+ER
 *
 * @param year
 *            the Gregorian year
 * @param month
 *            the Gregorian month. Unlike the Java Calendar where January has the value of 0,This expects a 1 for
 *            January
 * @param dayOfMonth
 *            the day of the month (1st, 2nd, etc...)
 * @return the absolute Gregorian day
 */
CREATE FUNCTION JewishDate_gregorianDateToAbsDate(year INTEGER UNSIGNED, month INTEGER UNSIGNED,
                                       dayOfMonth INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    DECLARE absDate INTEGER UNSIGNED DEFAULT dayOfMonth;
    DECLARE m INTEGER UNSIGNED DEFAULT month - 1;

    WHILE m > 0
        DO
            SET absDate = absDate + JewishDate_getLastDayOfGregorianMonth(m, year); # days in prior months of the year

            SET m = m - 1;
        END WHILE;

    RETURN absDate # days this year
               + 365 * (year - 1) # days in previous years ignoring leap days
               + TRUNCATE((year - 1) / 4, 0) # Julian leap days before this year
               - TRUNCATE((year - 1) / 100, 0) # minus prior century years
        + TRUNCATE((year - 1) / 400, 0); # plus prior years divisible by 400

END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.getLastMonthOfJewishYear()
/**
 * Returns the last month of a given Jewish year. This will be 12 on a non {@link #isJewishLeapYear(int) leap year}
 * or 13 on a leap year.
 *
 * @param year
 *            the Jewish year.
 * @return 12 on a non leap year or 13 on a leap year
 * @see #isJewishLeapYear(int)
 */
CREATE FUNCTION JewishDate_getLastMonthOfJewishYear(year INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN

    /**
   * Value of the month field indicating Adar (or Adar I in a {@link #isJewishLeapYear() leap year}), the twelfth
   * numeric month of the year in the Jewish calendar. With the year starting at {@link #TISHREI}, it would actually
   * be the 6th month of the year.
   */
    DECLARE ADAR INTEGER UNSIGNED DEFAULT 12;

    /**
     * Value of the month field indicating Adar II, the leap (intercalary or embolismic) thirteenth (Undecimber) numeric
     * month of the year added in Jewish {@link #isJewishLeapYear() leap year}). The leap years are years 3, 6, 8, 11,
     * 14, 17 and 19 of a 19 year cycle. With the year starting at {@link #TISHREI}, it would actually be the 7th month
     * of the year.
     */
    DECLARE ADAR_II INTEGER UNSIGNED DEFAULT 13;

    RETURN IF(JewishDate_isJewishLeapYear(year), ADAR_II, ADAR);

END ;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.getDaysSinceStartOfJewishYear()
/**
 * returns the number of days from Rosh Hashana of the date passed in, to the full date passed in.
 *
 * @param year
 *            the Jewish year
 * @param month
 *            the Jewish month
 * @param dayOfMonth
 *            the day in the Jewish month
 * @return the number of days
 */
CREATE FUNCTION JewishDate_getDaysSinceStartOfJewishYear(year INTEGER UNSIGNED, month INTEGER UNSIGNED,
                                              dayOfMonth INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    /**
     * Value of the month field indicating Nissan, the first numeric month of the year in the Jewish calendar. With the
     * year starting at {@link #TISHREI}, it would actually be the 7th (or 8th in a {@link #isJewishLeapYear() leap
     * year}) month of the year.
     */
    DECLARE NISSAN INTEGER UNSIGNED DEFAULT 1;
    /**
     * Value of the month field indicating Tishrei, the seventh numeric month of the year in the Jewish calendar. With
     * the year starting at this month, it would actually be the 1st month of the year.
     */
    DECLARE TISHREI INTEGER UNSIGNED DEFAULT 7;

    DECLARE elapsedDays INTEGER UNSIGNED DEFAULT dayOfMonth;
    DECLARE m INTEGER UNSIGNED DEFAULT 0;
    # Before Tishrei (from Nissan to Tishrei), add days in prior months
    IF (month < TISHREI) THEN
        # this year before and after Nisan.
        SET m = TISHREI;
        WHILE m <= JewishDate_getLastMonthOfJewishYear(year)
            DO
                SET elapsedDays = elapsedDays + JewishDate_getDaysInJewishMonth(m, year);
                SET m = m + 1;
            END WHILE;

        SET m = NISSAN;
        WHILE m < month
            DO
                SET elapsedDays = elapsedDays + JewishDate_getDaysInJewishMonth(m, year);
                SET m = m + 1;
            END WHILE;

    ELSE # Add days in prior months this year
        SET m = TISHREI;
        WHILE m < month
            DO
                SET elapsedDays = elapsedDays + JewishDate_getDaysInJewishMonth(m, year);
                SET m = m + 1;
            END WHILE;

    END IF;

    RETURN elapsedDays;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.jewishDateToAbsDate()
/**
 * Returns the absolute date of Jewish date. ND+ER
 *
 * @param year
 *            the Jewish year. The year can't be negative
 * @param month
 *            the Jewish month starting with Nisan. Nisan expects a value of 1 etc till Adar with a value of 12. For
 *            a leap year, 13 will be the expected value for Adar II. Use the constants {@link JewishDate#NISSAN}
 *            etc.
 * @param dayOfMonth
 *            the Jewish day of month. valid values are 1-30. If the day of month is set to 30 for a month that only
 *            has 29 days, the day will be set as 29.
 * @return the absolute date of the Jewish date.
 */
CREATE FUNCTION JewishDate_jewishDateToAbsDate(year INTEGER UNSIGNED, month INTEGER UNSIGNED,
                                    dayOfMonth INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    /**
     * the Jewish epoch using the RD (Rata Die/Fixed Date or Reingold Dershowitz) day used in Calendrical Calculations.
     * Day 1 is January 1, 0001 Gregorian
     */
    DECLARE JEWISH_EPOCH INTEGER DEFAULT -1373429;

    DECLARE elapsed INTEGER UNSIGNED DEFAULT JewishDate_getDaysSinceStartOfJewishYear(year, month, dayOfMonth);
    # add elapsed days this year + Days in prior years + Days elapsed before absolute year 1
    RETURN elapsed + JewishDate_getJewishCalendarElapsedDays(year) + JEWISH_EPOCH;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.getJewishMonthOfYear()
/**
 * Converts the {@link JewishDate#NISSAN} based constants used by this class to numeric month starting from
 * {@link JewishDate#TISHREI}. This is required for Molad calculations.
 *
 * @param year
 *            The Jewish year
 * @param month
 *            The Jewish Month
 * @return the Jewish month of the year starting with Tishrei
 */
CREATE FUNCTION JewishDate_getJewishMonthOfYear(year INTEGER UNSIGNED, month INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    DECLARE isLeapYear BOOLEAN DEFAULT JewishDate_isJewishLeapYear(year);
    RETURN ((month + IF(isLeapYear, 6, 5)) % IF(isLeapYear, 13, 12)) + 1;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.getChalakimSinceMoladTohu()
/**
 * Returns the number of chalakim (parts - 1080 to the hour) from the original hypothetical Molad Tohu to the year
 * and month passed in.
 *
 * @param year
 *            the Jewish year
 * @param month
 *            the Jewish month the Jewish month, with the month numbers starting from Nisan. Use the JewishDate
 *            constants such as {@link JewishDate#TISHREI}.
 * @return the number of chalakim (parts - 1080 to the hour) from the original hypothetical Molad Tohu
 */
CREATE FUNCTION JewishDate_getChalakimSinceMoladTohu(year INTEGER UNSIGNED, month INTEGER UNSIGNED) RETURNS BIGINT UNSIGNED
    DETERMINISTIC
BEGIN
    /**
     * Days from the beginning of Sunday till molad BaHaRaD. Calculated as 1 day, 5 hours and 204 chalakim = (24 + 5) *
     * 1080 + 204 = 31524
     */
    DECLARE CHALAKIM_MOLAD_TOHU INTEGER UNSIGNED DEFAULT 31524;
    /** The number  of <em>chalakim</em> in an average Jewish month. A month has 29 days, 12 hours and 793
     * <em>chalakim</em> (44 minutes and 3.3 seconds) for a total of 765,433 <em>chalakim</em> */
    DECLARE CHALAKIM_PER_MONTH INTEGER UNSIGNED DEFAULT 765433;
    # (29 * 24 + 12) * 1080 + 793


    # Jewish lunar month = 29 days, 12 hours and 793 chalakim
    # chalakim since Molad Tohu BeHaRaD - 1 day, 5 hours and 204 chalakim
    DECLARE monthOfYear INTEGER UNSIGNED DEFAULT JewishDate_getJewishMonthOfYear(year, month);
    DECLARE monthsElapsed INTEGER UNSIGNED DEFAULT
        (235 * FLOOR((year - 1) / 19)) # Months in complete 19 year lunar (Metonic) cycles so far
            + (12 * ((year - 1) % 19)) # Regular months in this cycle
            + FLOOR((7 * ((year - 1) % 19) + 1) / 19) # Leap months this cycle
            + (monthOfYear - 1);
    # add elapsed months till the start of the molad of the month
    # return chalakim prior to BeHaRaD + number of chalakim since
    RETURN CHALAKIM_MOLAD_TOHU + (CHALAKIM_PER_MONTH * monthsElapsed);

END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.isJewishLeapYear()
/**
 * Returns if the year is a Jewish leap year. Years 3, 6, 8, 11, 14, 17 and 19 in the 19 year cycle are leap years.
 *
 * @param year
 *            the Jewish year.
 * @return true if it is a leap year
 * @see #isJewishLeapYear()
 */
CREATE FUNCTION JewishDate_isJewishLeapYear(year INTEGER UNSIGNED) RETURNS BOOLEAN
    DETERMINISTIC
BEGIN
    RETURN ((7 * year) + 1) % 19 < 7;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.addDechiyos()
/**
 * Adds the 4 dechiyos for molad Tishrei. These are:
 * <ol>
 * <li>Lo ADU Rosh - Rosh Hashana can't fall on a Sunday, Wednesday or Friday. If the molad fell on one of these
 * days, Rosh Hashana is delayed to the following day.</li>
 * <li>Molad Zaken - If the molad of Tishrei falls after 12 noon, Rosh Hashana is delayed to the following day. If
 * the following day is ADU, it will be delayed an additional day.</li>
 * <li>GaTRaD - If on a non leap year the molad of Tishrei falls on a Tuesday (Ga) on or after 9 hours (T) and 204
 * chalakim (TRaD) it is delayed till Thursday (one day delay, plus one day for Lo ADU Rosh)</li>
 * <li>BeTuTaKFoT - if the year following a leap year falls on a Monday (Be) on or after 15 hours (Tu) and 589
 * chalakim (TaKFoT) it is delayed till Tuesday</li>
 * </ol>
 *
 * @param year the year
 * @param moladDay the molad day
 * @param moladParts the molad parts
 * @return the number of elapsed days in the JewishCalendar adjusted for the 4 dechiyos.
 */
CREATE FUNCTION JewishDate_addDechiyos(year INTEGER UNSIGNED, moladDay INTEGER UNSIGNED,
                            moladParts INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    DECLARE roshHashanaDay INTEGER UNSIGNED DEFAULT moladDay;
    # if no dechiyos

    # delay Rosh Hashana for the dechiyos of the Molad - new moon 1 - Molad Zaken, 2- GaTRaD 3- BeTuTaKFoT
    IF ((moladParts >= 19440) # Dechiya of Molad Zaken - molad is >= midday (18 hours * 1080 chalakim)
        || (((moladDay % 7) = 2) # start Dechiya of GaTRaD - Ga = is a Tuesday
            && (moladParts >= 9924) # TRaD = 9 hours, 204 parts or later (9 * 1080 + 204)
            && !JewishDate_isJewishLeapYear(year)) # of a non-leap year - end Dechiya of GaTRaD
        || (((moladDay % 7) = 1) # start Dechiya of BeTuTaKFoT - Be = is on a Monday
            && (moladParts >= 16789) # TRaD = 15 hours, 589 parts or later (15 * 1080 + 589)
            && (JewishDate_isJewishLeapYear(year - 1)))) THEN # in a year following a leap year - end Dechiya of BeTuTaKFoT
        SET roshHashanaDay = roshHashanaDay + 1; # Then postpone Rosh HaShanah one day
    END IF;

    # start 4th Dechiya - Lo ADU Rosh - Rosh Hashana can't occur on A- sunday, D- Wednesday, U - Friday
    IF (((roshHashanaDay % 7) = 0) # If Rosh HaShanah would occur on Sunday,
        || ((roshHashanaDay % 7) = 3) # or Wednesday,
        || ((roshHashanaDay % 7) = 5)) THEN # or Friday - end 4th Dechiya - Lo ADU Rosh
        SET roshHashanaDay = roshHashanaDay + 1; # Then postpone it one (more) day
    END IF;

    RETURN roshHashanaDay;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.getJewishCalendarElapsedDays()
/**
 * Returns the number of days elapsed from the Sunday prior to the start of the Jewish calendar to the mean
 * conjunction of Tishri of the Jewish year.
 *
 * @param year
 *            the Jewish year
 * @return the number of days elapsed from prior to the molad Tohu BaHaRaD (Be = Monday, Ha= 5 hours and Rad =204
 *         chalakim/parts) prior to the start of the Jewish calendar, to the mean conjunction of Tishri of the
 *         Jewish year. BeHaRaD is 23:11:20 on Sunday night(5 hours 204/1080 chalakim after sunset on Sunday
 *         evening).
 */
CREATE FUNCTION JewishDate_getJewishCalendarElapsedDays(year INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    /** The number of chalakim (25,920) in a 24 hour day. */
    DECLARE CHALAKIM_PER_DAY INTEGER DEFAULT 25920;
    # 24 * 1080
    /**
     * Value of the month field indicating Tishrei, the seventh numeric month of the year in the Jewish calendar. With
     * the year starting at this month, it would actually be the 1st month of the year.
     */
    DECLARE TISHREI INTEGER UNSIGNED DEFAULT 7;

    DECLARE chalakimSince BIGINT DEFAULT JewishDate_getChalakimSinceMoladTohu(year, TISHREI);
    DECLARE moladDay INTEGER UNSIGNED DEFAULT FLOOR(chalakimSince / CHALAKIM_PER_DAY);
    DECLARE moladParts INTEGER UNSIGNED DEFAULT FLOOR(chalakimSince - moladDay * CHALAKIM_PER_DAY);
    # delay Rosh Hashana for the 4 dechiyos
    RETURN JewishDate_addDechiyos(year, moladDay, moladParts);
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.getDaysInJewishYear()
/**
 * Returns the number of days for the current year that the calendar is set to.
 *
 * @return the number of days for the Object's current Jewish year.
 * @see #isCheshvanLong()
 * @see #isKislevShort()
 * @see #isJewishLeapYear()
 */
CREATE FUNCTION JewishDate_getDaysInJewishYear(year INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    RETURN JewishDate_getJewishCalendarElapsedDays(year + 1) - JewishDate_getJewishCalendarElapsedDays(year);
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.isCheshvanLong()
/**
 * Returns if Cheshvan is long in a given Jewish year. The method name isLong is done since in a Kesidran (ordered)
 * year Cheshvan is short. ND+ER
 *
 * @param year
 *            the year
 * @return true if Cheshvan is long in Jewish year.
 * @see #isCheshvanLong()
 * @see #getCheshvanKislevKviah()
 */
CREATE FUNCTION JewishDate_isCheshvanLong(year INTEGER UNSIGNED) RETURNS BOOLEAN
    DETERMINISTIC
BEGIN
    RETURN (JewishDate_getDaysInJewishYear(year) % 10) = 5;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.isKislevShort()
/**
 * Returns if Kislev is short (29 days VS 30 days) in a given Jewish year. The method name isShort is done since in
 * a Kesidran (ordered) year Kislev is long. ND+ER
 *
 * @param year
 *            the Jewish year
 * @return true if Kislev is short for the given Jewish year.
 * @see #isKislevShort()
 * @see #getCheshvanKislevKviah()
 */
CREATE FUNCTION JewishDate_isKislevShort(year INTEGER UNSIGNED) RETURNS BOOLEAN
    DETERMINISTIC
BEGIN
    RETURN (JewishDate_getDaysInJewishYear(year) % 10) = 3;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.getDaysInJewishMonth()
/**
 * Returns the number of days of a Jewish month for a given month and year.
 *
 * @param month
 *            the Jewish month
 * @param year
 *            the Jewish Year
 * @return the number of days for a given Jewish month
 */
CREATE FUNCTION JewishDate_getDaysInJewishMonth(month INTEGER UNSIGNED, year INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
BEGIN
    /**
     * Value of the month field indicating Iyar, the second numeric month of the year in the Jewish calendar. With the
     * year starting at {@link #TISHREI}, it would actually be the 8th (or 9th in a {@link #isJewishLeapYear() leap
     * year}) month of the year.
     */
    DECLARE IYAR INTEGER UNSIGNED DEFAULT 2;

    /**
     * Value of the month field indicating Tammuz, the fourth numeric month of the year in the Jewish calendar. With the
     * year starting at {@link #TISHREI}, it would actually be the 10th (or 11th in a {@link #isJewishLeapYear() leap
     * year}) month of the year.
     */
    DECLARE TAMMUZ INTEGER UNSIGNED DEFAULT 4;

    /**
     * Value of the month field indicating Elul, the sixth numeric month of the year in the Jewish calendar. With the
     * year starting at {@link #TISHREI}, it would actually be the 12th (or 13th in a {@link #isJewishLeapYear() leap
     * year}) month of the year.
     */
    DECLARE ELUL INTEGER UNSIGNED DEFAULT 6;

    /**
     * Value of the month field indicating Cheshvan/marcheshvan, the eighth numeric month of the year in the Jewish
     * calendar. With the year starting at {@link #TISHREI}, it would actually be the 2nd month of the year.
     */
    DECLARE CHESHVAN INTEGER UNSIGNED DEFAULT 8;

    /**
     * Value of the month field indicating Kislev, the ninth numeric month of the year in the Jewish calendar. With the
     * year starting at {@link #TISHREI}, it would actually be the 3rd month of the year.
     */
    DECLARE KISLEV INTEGER UNSIGNED DEFAULT 9;

    /**
     * Value of the month field indicating Teves, the tenth numeric month of the year in the Jewish calendar. With the
     * year starting at {@link #TISHREI}, it would actually be the 4th month of the year.
     */
    DECLARE TEVES INTEGER UNSIGNED DEFAULT 10;

    /**
     * Value of the month field indicating Adar (or Adar I in a {@link #isJewishLeapYear() leap year}), the twelfth
     * numeric month of the year in the Jewish calendar. With the year starting at {@link #TISHREI}, it would actually
     * be the 6th month of the year.
     */
    DECLARE ADAR INTEGER UNSIGNED DEFAULT 12;

    /**
     * Value of the month field indicating Adar II, the leap (intercalary or embolismic) thirteenth (Undecimber) numeric
     * month of the year added in Jewish {@link #isJewishLeapYear() leap year}). The leap years are years 3, 6, 8, 11,
     * 14, 17 and 19 of a 19 year cycle. With the year starting at {@link #TISHREI}, it would actually be the 7th month
     * of the year.
     */
    DECLARE ADAR_II INTEGER UNSIGNED DEFAULT 13;

    IF month IN (IYAR, TAMMUZ, ELUL, ADAR_II) OR (month = CHESHVAN AND NOT JewishDate_isCheshvanLong(year)) OR
       (month = KISLEV AND JewishDate_isKislevShort(year)) OR (month = TEVES) OR
       (month = ADAR AND NOT JewishDate_isJewishLeapYear(year))
    THEN
        RETURN 29;
    ELSE
        RETURN 30;
    END IF;
END;;

#-----------------------------------------------------------------------------------------------------------------------

# JewishDate.absDateToJewishDate()
/**
 * Computes the Jewish date from the absolute date.
 */
CREATE PROCEDURE JewishDate_absDateToJewishDate(gregorianAbsDate INTEGER UNSIGNED, OUT jewishYear INTEGER UNSIGNED,
                                     OUT jewishMonth INTEGER UNSIGNED, OUT jewishDay INTEGER UNSIGNED)
    DETERMINISTIC
BEGIN
    /**
     * the Jewish epoch using the RD (Rata Die/Fixed Date or Reingold Dershowitz) day used in Calendrical Calculations.
     * Day 1 is January 1, 0001 Gregorian
     */
    DECLARE JEWISH_EPOCH INTEGER DEFAULT -1373429;
    /**
     * Value of the month field indicating Nissan, the first numeric month of the year in the Jewish calendar. With the
     * year starting at {@link #TISHREI}, it would actually be the 7th (or 8th in a {@link #isJewishLeapYear() leap
     * year}) month of the year.
     */
    DECLARE NISSAN INTEGER UNSIGNED DEFAULT 1;
    /**
     * Value of the month field indicating Tishrei, the seventh numeric month of the year in the Jewish calendar. With
     * the year starting at this month, it would actually be the 1st month of the year.
     */
    DECLARE TISHREI INTEGER UNSIGNED DEFAULT 7;

    # Approximation from below
    SET jewishYear = FLOOR((gregorianAbsDate - JEWISH_EPOCH) / 366);

    # Search forward for year from the approximation
    WHILE (gregorianAbsDate >= JewishDate_jewishDateToAbsDate(jewishYear + 1, TISHREI, 1))
        DO
            SET jewishYear = jewishYear + 1;
        END WHILE;

    # Search forward for month from either Tishri or Nisan.
    IF gregorianAbsDate < JewishDate_jewishDateToAbsDate(jewishYear, NISSAN, 1) THEN
        SET jewishMonth = TISHREI;
    ELSE
        SET jewishMonth = NISSAN;
    END IF;

    WHILE (gregorianAbsDate >
           JewishDate_jewishDateToAbsDate(jewishYear, jewishMonth, JewishDate_getDaysInJewishMonth(jewishMonth, jewishYear)))
        DO
            SET jewishMonth = jewishMonth + 1;
        END WHILE;

    # Calculate the day by subtraction
    SET jewishDay = gregorianAbsDate - JewishDate_jewishDateToAbsDate(jewishYear, jewishMonth, 1) + 1;


END ;;

#-----------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE gregorian_date_to_jewish_date(IN year INTEGER UNSIGNED, IN month INTEGER UNSIGNED,
                                               IN day INTEGER UNSIGNED, OUT jewishYear INTEGER UNSIGNED,
                                               OUT jewishMonth INTEGER UNSIGNED, OUT jewishDay INTEGER UNSIGNED)
    DETERMINISTIC
BEGIN
    # 	declare gregorianMonth integer unsigned default month;
# 	declare gregorianDayOfMonth integer unsigned default day;
# 	declare gregorianYear integer unsigned default year;
    DECLARE gregorianAbsDate INTEGER UNSIGNED DEFAULT 0;

    SET gregorianAbsDate = JewishDate_gregorianDateToAbsDate(year, month, day);

    CALL JewishDate_absDateToJewishDate(gregorianAbsDate, jewishYear, jewishMonth, jewishDay);
END;;

DELIMITER ;
