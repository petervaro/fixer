/* INFO **
** INFO */

import std.stdio            : stderr,
                              writeln;
import std.net.curl         : get,
                              CurlException;
import std.file             : exists,
                              write,
                              readText,
                              timeLastModified,
                              FileException;
import std.json             : JSONValue,
                              parseJSON,
                              JSONException;
import std.string           : toUpper;
import std.format           : format;
import std.conv             : to;
import std.datetime.systime : Clock;

version (Posix)
    import std.datetime.timezone : PosixTimeZone;
else version (Windows)
    import std.datetime.timezone : WindowsTimeZone;


/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
enum
{
    ExitSuccess,
    ExitFailure,
}

/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
enum RatesJSON = "fixer.json";


/*----------------------------------------------------------------------------*/
immutable usageText = "
Foreign exchange rates and currency converter
Usage: fixer <amount> <currency-from> [in|to] <currency-to>
Help: -h or --help
";


/*----------------------------------------------------------------------------*/
immutable helpText = "
NAME
    fixer - Foreign exchange rates and currency converter

SYNOPSIS
    fixer [OPTIONS] | AMOUNT FROM [in|to] TO

DESCRIPTION
    Command line currency converter implemented in D, based on the daily updated
    rates available from <http://fixer.io>.  For more information please visit
    the repository of the project at <https://gitlab.com/petervaro/fixer>.

OPTIONS
    -h, --help
        Prints this text.

AMOUNT
    Integer or floating point number

FROM
    Case insensitive CURRENCY to convert the AMOUNT from

TO
    Case insensitive CURRENCY to convert the AMOUNT to

CURRENCY
    One of the following values:
        AUD - Australian Dollar
        BGN - Bulgarian Lev
        BRL - Brazilian Real
        CAD - Canadian Dollar
        CHF - Swiss Franc
        CNY - Chinese Yuan
        CZK - Czech Koruna
        DKK - Danish Krone
        EUR - European Union Euro
        GBP - Great British Pound
        HKD - Hong Kong Dollar
        HRK - Croatian Kuna
        HUF - Hungarian Forint
        IDR - Indonesian Rupiah
        ILS - Israeli Shekel
        INR - Indian Rupee
        JPY - Japanese Yen
        KRW - South Korean Won
        MXN - Mexican Peso
        MYR - Malaysian Ringgit
        NOK - Norwegian Krone
        NZD - New Zealand Dollar
        PHP - Philippine Peso
        PLN - Polish Zloty
        RON - Romanian New Leu
        RUB - Russian Rouble
        SEK - Swedish Krona
        SGD - Singapore Dollar
        THB - Thai Baht
        TRY - Turkish Lira
        USD - United States Dollar
        ZAR - South African Rand

EXAMPLE
    $ fixer 1 usd eur
    $ fixer 2000 jpy in gpb
    $ fixer 99 NOK to SEK

AUTHOR
    Written by Peter Varo.

LICENSE
    Copyright (C) 2017 Peter Varo

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation, either version 3 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANYWARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
    details.

    You should have received a copy of the GNU General Public License along with
    this program, most likely a file in the root directory, called 'LICENSE'. If
    not, see http://www.gnu.org/licenses.
";


/*----------------------------------------------------------------------------*/
int
main(string[] argv)
{
    /* Handle arguments */
    if (argv.length <= 1)
    {
        writeln(usageText);
        return ExitSuccess;
    }
    else if (argv[1] == "-h" ||
             argv[1] == "--help")
    {
        writeln(helpText);
        return ExitSuccess;
    }

    if (argv.length < 4)
    {
        stderr.writeln("Too few arguments. For more info try --help");
        return ExitFailure;
    }

    immutable amount       = to!double(argv[1]);
    string    fromCurrency = toUpper(argv[2]),
              toCurrency   = toUpper(argv[$ > 4 ? 4 : 3]);

    JSONValue rates;
    bool      getLatestRates = true;

    /* Try to use existing local data if it is not too old */
    if (exists(RatesJSON))
    {
        version (Posix)
            immutable fixerTZ = PosixTimeZone.getTimeZone("CET");
        else version (Windows)
            immutable fixerTZ = WindowsTimeZone.getTimeZone("CET");

        immutable localTime    = Clock.currTime(fixerTZ);
        immutable fileModified = timeLastModified(RatesJSON).toOtherTZ(fixerTZ);

        /* If file was edited today and older than 4PM */
        if (fileModified.year  == localTime.year  &&
            fileModified.month == localTime.month &&
            /* Yesterday after 4PM */
            ((fileModified.day == localTime.day - 1 &&
              fileModified.hour > 16) ||
            /* Today before 4PM */
             (fileModified.day == localTime.day &&
              fileModified.hour < 16)))
        {
            try
            {
                rates = parseJSON(readText(RatesJSON));
            }
            catch (FileException error)
            {
                stderr.writeln("Cannot read rates from file '",
                               RatesJSON, "': ", error.msg);
                return ExitFailure;
            }
            catch (JSONException error)
            {
                stderr.writeln("Invalid rates in file '", RatesJSON,
                               "' (expected valid JSON): ", error.msg);
                return ExitFailure;
            }
            getLatestRates = false;
        }
    }

    /* Get latest rates, parse the response JSON and save into a file */
    if (getLatestRates)
        try
        {
            const(char[]) response = get("https://api.fixer.io/latest");
            rates = parseJSON(response);
            write(RatesJSON, response);
        }
        catch (CurlException error)
        {
            stderr.writeln(
                "Connection error (something went wrong during a GET): ",
                error.msg);
            return ExitFailure;
        }
        catch (JSONException error)
        {
            stderr.writeln(
                "Invalid response from server (expected valid JSON): ",
                error.msg);
            return ExitFailure;
        }
        catch (FileException error)
        {
            stderr.writeln(
                "Cannot save rates to file '", RatesJSON, "': ", error.msg);
            return ExitFailure;
        }

    /* Get rates */
    rates = rates.object["rates"];
    immutable from =
        fromCurrency == "EUR" ? 1.0 : rates.object[fromCurrency].floating;
    immutable to =
        toCurrency == "EUR" ? 1.0 : rates.object[toCurrency].floating;

    /* Calculate, format and print the conversion */
    writeln(format("%.2f", amount/from*to));
    return ExitSuccess;
}