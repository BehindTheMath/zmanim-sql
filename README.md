## This project is at an alpha stage.

Things will break, and APIs might change. Be cautious using this in production.
Additionally, not all methods have been tested for accuracy.

# Introduction
zmanim.sql is a partial SQL port of the [KosherJava](KosherJava/zmanim) library.

The dialect used is MySQL.

# Installation
Run the scripts in the context of your DB.

# Usage and Documentation
### Pure static KosherJava methods
In general, pure static KosherJava methods were converted to deterministic functions.

E.g., in `JewishDate`:
```java
private static int getLastDayOfGregorianMonth(int month, int year)
```

was converted to:
```sql
CREATE FUNCTION JewishDate_getLastDayOfGregorianMonth(month INTEGER UNSIGNED, year INTEGER UNSIGNED) RETURNS INTEGER UNSIGNED
    DETERMINISTIC
```
### Impure instance methods
Impure instance methods were usually converted to stored procedures that return multiple `out` parameters,
with the `out` parameters corresponding to the instance methods that are mutated.

E.g., in `JewishDate`:
```java
private void absDateToJewishDate()
```
which uses instance property `gregorianAbsDate` and mutates instance properties  `jewishYear`, `jewishMonth`, and `jewishDay`,
was converted to:
```sql
CREATE PROCEDURE JewishDate_absDateToJewishDate(gregorianAbsDate INTEGER UNSIGNED, OUT jewishYear INTEGER UNSIGNED,
                                     OUT jewishMonth INTEGER UNSIGNED, OUT jewishDay INTEGER UNSIGNED)
    DETERMINISTIC
```
### Helper procedures
Some helper procedures have been added to take the places of constructors and methods that only make sense in an instance context.

E.g. instead of the following:
```java
Calendar calendar = Calendar.getInstance();
calendar.set(2023, Calendar.DECEMBER, 31);
JewishDate jewishDate = new JewishDate(calendar);
int jewishYear = jewishDate.getJewishYear();
int jewishMonth = jewishDate.getJewishMonth();
int jewishDay = jewishDate.getJewishDayOfMonth();
```
use the following:
```sql
CALL gregorian_date_to_jewish_date(2023, 12, 31, @jewishYear, @jewishMonth, @jewishDay);
select @jewishYear, @jewishMonth, @jewishDay;
```
