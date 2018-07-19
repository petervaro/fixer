/* INFO **
** INFO */

import std.stdio            : stderr,
                              writeln,
                              writefln;
import std.net.curl         : get,
                              CurlException;
import std.file             : exists,
                              write,
                              readText,
                              timeLastModified,
                              mkdirRecurse,
                              FileException;
import std.path             : expandTilde;
import std.json             : JSONValue,
                              JSON_TYPE,
                              parseJSON,
                              JSONException;
import std.string           : toUpper,
                              strip;
import std.format           : format;
import std.conv             : to,
                              ConvException;
import std.datetime.systime : Clock;

version (Posix)
    import std.datetime.timezone : TimeZone = PosixTimeZone;
else version (Windows)
    import std.datetime.timezone : TimeZone = WindowsTimeZone;


/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
enum
{
    ExitSuccess,
    ExitFailure,
}

/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
enum BaseDir          = "~/.fixer";
enum RatesFile        = "latest-rates.json";
enum APIAccessKeyFile = "api-access-key.txt";


/*----------------------------------------------------------------------------*/
immutable usageText = "
Foreign exchange rates and currency converter (more info: --help)
   fixer <amount> <currency-from> [in|to] <currency-to>
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
    not, see <http://www.gnu.org/licenses>.
";


/*----------------------------------------------------------------------------*/
int
main(string[] argv)
{
    // TODO: Implement support for historical rates: -H, --history 2010-01-10

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

    double amount;
    try
    {
        amount = to!double(argv[1]);
    }
    catch (ConvException error)
    {
        stderr.writeln(
            "First argument is not a number: ", argv[1], ": ", error.msg);
        return ExitFailure;
    }

    string    fromCurrency = argv[2].toUpper,
              toCurrency   = argv[$ > 4 ? 4 : 3].toUpper;

    JSONValue rates;
    bool      getLatestRates = true;
    string    ratesPath      = expandTilde(BaseDir ~ "/" ~ RatesFile);
    string    accessPath     = expandTilde(BaseDir ~ "/" ~ APIAccessKeyFile);

    if (!accessPath.exists)
    {
        stderr.writeln("Missing API access key.  Get a free one from: " ~
                       "https://fixer.io and save it in: ", accessPath);
        return ExitFailure;
    }

    /* Try to use existing local data if it is not too old */
    if (ratesPath.exists)
    {
        immutable fixerTZ      = TimeZone.getTimeZone("CET");
        immutable localTime    = Clock.currTime(fixerTZ);
        immutable fileModified = timeLastModified(ratesPath).toOtherTZ(fixerTZ);

        /* If file was edited at the same hour of current execution */
        if (fileModified.year  == localTime.year  &&
            fileModified.month == localTime.month &&
            fileModified.day   == localTime.day &&
            fileModified.hour  == localTime.hour)
        {
            try
            {
                rates = ratesPath.readText.parseJSON;
            }
            catch (FileException error)
            {
                stderr.writeln("Cannot read rates from file '",
                               ratesPath, "': ", error.msg);
                return ExitFailure;
            }
            catch (JSONException error)
            {
                stderr.writeln("Invalid rates in file '", ratesPath,
                               "' (expected valid JSON): ", error.msg);
                return ExitFailure;
            }
            getLatestRates = false;
        }
    }

    /* Get latest rates, parse the response JSON and save into a file */
    if (getLatestRates)
    {
        string apiAccessKey;

        /* Get API access key */
        try
            apiAccessKey = accessPath.readText.strip;
        catch (FileException error)
        {
            stderr.writeln("Cannot read API access key from file '",
                           accessPath, "': ", error.msg);
            return ExitFailure;
        }

        char[] response;

        /* Download rates */
        try
        {
            response = get("http://data.fixer.io/api/latest?access_key=" ~
                           apiAccessKey ~ "&base=EUR");
            rates    = response.parseJSON;
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
                "Cannot save rates to file '", ratesPath, "': ", error.msg);
            return ExitFailure;
        }

        /* Create folders for the file and save it */
        string ratesDir = ratesPath[0..$ - (RatesFile.length + 1)];
        try
        {
            mkdirRecurse(ratesDir);
        }
        catch (FileException error)
        {
            stderr.writeln(
                "Cannot create directories '", ratesDir, "': ", error.msg);
            return ExitFailure;
        }

        try
        {
            write(ratesPath, response);
        }
        catch (FileException error)
        {
            stderr.writeln(
                "Cannot write rates to file '", ratesPath, "': ", error.msg);
            return ExitFailure;
        }
    }

    /* Validate and sanitise data from the JSON */
    if (rates.type != JSON_TYPE.OBJECT)
    {
        stderr.writeln("Invalid JSON format in file '", ratesPath,
                       "': expected Object at the top-level");
        return ExitFailure;
    }
    else if ("rates" !in rates)
    {
        stderr.writeln("Invalid JSON format in file '", ratesPath,
                       "': extepected to have a \"rates\" key");
        return ExitFailure;
    }

    rates = rates.object["rates"];
    if (rates.type != JSON_TYPE.OBJECT)
    {
        stderr.writeln("Invalid JSON format in file '", ratesPath,
                       "': expected Object for the key \"rates\"");
        return ExitFailure;
    }
    else if (fromCurrency != "EUR")
    {
        if (fromCurrency !in rates)
        {
            stderr.writeln("Unknown currency: ", fromCurrency);
            return ExitFailure;
        }
        else if (rates.object[fromCurrency].type != JSON_TYPE.FLOAT)
        {
            stderr.writeln("Invalid JSON format in file '", ratesPath,
                           "': expected number for the key \"", fromCurrency,
                           "\"");
            return ExitFailure;
        }
    }
    else if (toCurrency != "EUR")
    {
        if (toCurrency !in rates)
        {
            stderr.writeln("Unknown currency: ", toCurrency);
            return ExitFailure;
        }
        else if (rates.object[toCurrency].type != JSON_TYPE.FLOAT)
        {
            stderr.writeln("Invalid JSON format in file '", ratesPath,
                           "': expected number for the key \"", toCurrency,
                           "\"");
            return ExitFailure;
        }
    }

    /* Get rates */
    immutable from =
        fromCurrency == "EUR" ? 1.0 : rates.object[fromCurrency].floating;
    immutable to =
        toCurrency == "EUR" ? 1.0 : rates.object[toCurrency].floating;

    /* Calculate, format and print the conversion */
    writefln("%.2f", amount/from*to);
    return ExitSuccess;
}
/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
unittest
{
    /* Test support texts */
    assert(main(["fixer"]) == ExitSuccess);
    assert(main(["fixer", "-h"]) == ExitSuccess);
    assert(main(["fixer", "--help"]) == ExitSuccess);

    /* Test invalid behaviours */
    assert(main(["fixer", "1"]) == ExitFailure);
    assert(main(["fixer", "1", "eur"]) == ExitFailure);
    assert(main(["fixer", "x", "gbp", "eur"]) == ExitFailure);
    assert(main(["fixer", "1", "x", "y"]) == ExitFailure);
    assert(main(["fixer", "1", "eur", "y"]) == ExitFailure);
    assert(main(["fixer", "1", "x", "eur"]) == ExitFailure);

    version (WithAPIAccessKey)
    {
        /* Test valid behaviours */
        assert(main(["fixer", "1", "gbp", "eur"]) == ExitSuccess);
        assert(main(["fixer", "1", "gbp", "in", "eur"]) == ExitSuccess);
        assert(main(["fixer", "1", "gbp", "to", "eur"]) == ExitSuccess);
    }
}
