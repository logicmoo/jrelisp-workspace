/*
 * CharacterInputStream.java
 *
 * Copyright (C) 2003 Peter Graves
 * $Id: CharacterInputStream.java,v 1.2 2003-02-23 02:09:59 piso Exp $
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

package org.armedbear.lisp;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PushbackReader;
import java.io.StringReader;

public class CharacterInputStream extends LispStream
{
    private final PushbackReader reader;
    private int offset;
    private int lineNumber;

    public CharacterInputStream(InputStream in)
    {
        reader = new PushbackReader(
            new BufferedReader(new InputStreamReader(in)),
            2);
    }

    public CharacterInputStream(String s)
    {
        reader = new PushbackReader(
            new BufferedReader(new StringReader(s)),
            2);
    }

    public int getOffset()
    {
        return offset;
    }

    public int getLineNumber()
    {
        return lineNumber;
    }

    public LispObject read(boolean eofError, LispObject eofValue,
        boolean recursive) throws LispError
    {
        try {
            LispObject result = readPreservingWhitespace(eofError, eofValue,
                recursive);
            if (result != eofValue && !recursive) {
                if (reader.ready()) {
                    int n = read();
                    if (n >= 0) {
                        char c = (char) n;
                        if (!Character.isWhitespace(c))
                            unread(c);
                    }
                }
            }
            return result;
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    public LispObject readPreservingWhitespace(boolean eofError,
        LispObject eofValue, boolean recursive) throws LispError
    {
        while (true) {
            LispObject obj = readChar(eofError, EOF);
            if (obj == EOF)
                return eofValue;
            LispCharacter character = (LispCharacter) obj;
            if (character.isWhitespace())
                continue;
            LispObject result = processChar(character.getValue());
            if (result != null)
                return result;
        }
    }

    private LispObject processChar(char c) throws LispError
    {
        switch (c) {
            case '"':
                return readString();
            case '\'':
                return readQuote();
            case '(':
                return readList();
            case ')':
                return readRightParen();
            case ';':
                return readComment();
            case ',':
                return readComma();
            case '`':
                return readBackquote();
            case '#':
                return readSharp();
            default:
                return readToken(c);
        }
    }

    private LispString readString() throws LispError
    {
        try {
            StringBuffer sb = new StringBuffer();
            while (true) {
                int n = read();
                if (n < 0)
                    throw new EndOfFileException();
                char c = (char) n;
                if (c == '\\') {
                    // Single escape.
                    n = read();
                    if (n < 0)
                        throw new EndOfFileException();
                    sb.append((char)n);
                    continue;
                }
                if (c == '"')
                    break;
                // Default.
                sb.append(c);
            }
            return new LispString(sb.toString());
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private LispObject readQuote() throws LispError
    {
        return new Cons(Symbol.QUOTE, new Cons(read(true, NIL, true)));
    }

    private LispObject readList() throws LispError
    {
        try {
            Cons first = null;
            Cons last = null;
            while (true) {
                char c = flushWhitespace();
                if (c == ')') {
                    return first == null ? NIL : first;
                }
                if (c == '.') {
                    int n = read();
                    if (n < 0)
                        throw new EndOfFileException();
                    char nextChar = (char) n;
                    if (isTokenDelimiter(nextChar)) {
                        if (last == null)
                            throw new LispError("nothing appears before . in list");
                        LispObject obj = read(true, NIL, true);
                        last.setCdr(obj);
                        continue;
                    } else {
                        // normal token beginning with '.'
                        unread(nextChar);
                    }
                }
                LispObject obj = processChar(c);
                if (obj == null) {
                    // A comment.
                    continue;
                }
                if (first == null) {
                    first = new Cons(obj, NIL);
                    last = first;
                } else {
                    last.setCdr(new Cons(obj, NIL));
                    last = (Cons) last.cdr();
                }
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private boolean isTokenDelimiter(char c)
    {
        switch (c) {
            case '"':
            case '\'':
            case '(':
            case ')':
            case ',':
            case ';':
            case '`':
                return true;
            default:
                return Character.isWhitespace(c);
        }
    }

    private LispObject readRightParen() throws LispError
    {
        throw new LispError("unmatched right parenthesis");
    }

    private LispObject readComment() throws LispError
    {
        try {
            while (true) {
                int n = read();
                if (n < 0)
                    return null;
                if (n == '\n')
                    return null;
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private LispObject readComma() throws LispError
    {
        try {
            int n = read();
            if (n < 0)
                throw new EndOfFileException();
            char c = (char) n;
            switch (c) {
                case '@':
                    return new Cons(Symbol.COMMA_ATSIGN,
                        new Cons(read(true, NIL, true), NIL));
                case '.':
                    return new Cons(Symbol.COMMA_DOT,
                        new Cons(read(true, NIL, true), NIL));
                default:
                    unread(c);
                    return new Cons(Symbol.COMMA,
                        new Cons(read(true, NIL, true), NIL));
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private LispObject readBackquote() throws LispError
    {
        return new Cons(Symbol.BACKQUOTE, new Cons(read(true, NIL, true)));
    }

    private LispObject readSharp() throws LispError
    {
        try {
            int n = read();
            if (n < 0)
                throw new EndOfFileException();
            char c = (char) n;
            switch (c) {
                case '\'':
                    return new Cons(Symbol.FUNCTION,
                        new Cons(read(true, NIL, true), NIL));
                case '(':
                    return new Vector(readList());
                case '\\':
                    return readChar(true, NIL);
                case '+':
                case '-':
                    return handleFeature(c);
                case ':':
                    return readUninternedSymbol();
                case '|':
                    skipBalancedComment();
                    return null;
                case '.':
                    return eval(read(true, NIL, true), new Environment());
                case '*':
                    return NIL;
                default:
                    //clearInput();
                    //throw new LispError("unsupported '#' macro character '" +
                    //    c + '\'');
                    return null;
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    // FIXME
    private LispObject handleFeature(char c) throws LispError
    {
        LispObject feature = read(true, NIL, true);
        LispObject form = read(true, NIL, true);
        if (feature instanceof Symbol) {
            if (((Symbol)feature).getName().equalsIgnoreCase("armedbear")) {
                if (c == '+')
                    return form;
                else
                    return null;
            } else {
                if (c == '+')
                    return null;
                else
                    return form;
            }
        }
        return null;
    }

    private Symbol readUninternedSymbol() throws LispError
    {
        try {
            StringBuffer sb = new StringBuffer();
            while (true) {
                int n = read();
                if (n < 0)
                    return new Symbol(sb.toString());
                char c = (char) n;
                if (Character.isWhitespace(c))
                    return new Symbol(sb.toString());
                switch (c) {
                    case '(':
                    case ')':
                        unread(c);
                        return new Symbol(sb.toString());
                    default:
                        sb.append(c);
                }
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private void skipBalancedComment() throws StreamError
    {
        try {
            while (true) {
                int n = read();
                if (n < 0)
                    return;
                if (n == '|') {
                    n = read();
                    if (n == '#')
                        return;
                } else if (n == '#') {
                    n = read();
                    if (n == '|')
                        skipBalancedComment(); // Nested comment. Recurse!
                }
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private LispObject readToken(char firstChar) throws LispError
    {
        try {
            StringBuffer sb = new StringBuffer();
            sb.append(firstChar);
            while (true) {
                int n = read();
                if (n < 0)
                    return makeObject(sb.toString());
                char c = (char) n;
                if (Character.isWhitespace(c))
                    return makeObject(sb.toString());
                switch (c) {
                    case '(':
                    case ')':
                        unread(c);
                        return makeObject(sb.toString());
                    default:
                        sb.append(c);
                }
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private LispObject makeObject(String token) throws LispError
    {
        char c = token.charAt(0);
        if (c == '-' || Character.isDigit(token.charAt(0))) {
            try {
                return new Fixnum(Integer.parseInt(token));
            }
            catch (NumberFormatException e) {
                // It's not really a number. Fall through...
            }
        }
        token = token.toUpperCase();
        if (token.equals("T"))
            return T;
        if (token.equals("NIL"))
            return NIL;
        if (c == ':') {
            Symbol symbol = intern(token.substring(1), PACKAGE_KEYWORD);
            symbol.setSymbolValue(symbol);
            symbol.setConstant(true);
            symbol.setExternal(true);
            return symbol;
        }
        int index = token.indexOf("::");
        if (index > 0) {
            String packageName = token.substring(0, index);
            String symbolName = token.substring(index + 2);
            Package pkg = Packages.findPackage(packageName);
            if (pkg == null)
                throw new LispError("package \"" + packageName +
                    "\" not found");
            return intern(symbolName, pkg);
        }
        index = token.indexOf(':');
        if (index > 0) {
            String packageName = token.substring(0, index);
            String symbolName = token.substring(index + 1);
            Package pkg = Packages.findPackage(packageName);
            if (pkg == null)
                throw new LispError("package \"" + packageName +
                    "\" not found");
            Symbol symbol = pkg.findSymbol(symbolName);
            if (symbol == null)
                throw new LispError("symbol \"" + symbolName +
                    "\" not found in package " + packageName);
            if (!symbol.isExternal())
                throw new LispError("symbol \"" + symbolName +
                    "\" is not external in package " + packageName);
            return symbol;
        }
        return intern(token, getCurrentPackage());
    }

    private char flushWhitespace() throws LispError
    {
        try {
            while (true) {
                int n = read();
                if (n < 0)
                    throw new EndOfFileException();
                char c = (char) n;
                if (!Character.isWhitespace(c))
                    return c;
            }
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    // read-line &optional stream eof-error-p eof-value recursive-p
    // => line, missing-newline-p
    // recursive-p is ignored
    public LispObject readLine(boolean eofError, LispObject eofValue)
        throws LispError
    {
        StringBuffer sb = new StringBuffer();
        while (true) {
            try {
                int n = read();
                if (n < 0) {
                    if (sb.length() == 0) {
                        if (eofError)
                            throw new EndOfFileException();
                        return eofValue;
                    }
                    return new LispString(sb.toString());
                }
                switch (n) {
                    case '\n':
                    case '\r':
                        return new LispString(sb.toString());
                    default:
                        sb.append((char)n);
                }
            }
            catch (IOException e) {
                throw new StreamError(e);
            }
        }
    }

    // read-char &optional stream eof-error-p eof-value recursive-p => char
    // recursive-p is ignored
    public LispObject readChar(boolean eofError, LispObject eofValue)
        throws LispError
    {
        int n;
        try {
            n = read();
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
        if (n < 0) {
            if (eofError)
                throw new EndOfFileException();
            else
                return eofValue;
        }
        return new LispCharacter((char)n);
    }

    // unread-char character &optional input-stream => nil
    public LispObject unreadChar(LispCharacter c) throws LispError
    {
        try {
            unread(c.getValue());
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
        return NIL;
    }

    // clear-input &optional input-stream => nil
    public LispObject clearInput() throws LispError
    {
        try {
            while (reader.ready())
                read();
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
        return NIL;
    }

    // close stream &key abort => result
    // Must return true if stream was open, otherwise implementation-dependent.
    public LispObject close(LispObject abort) throws StreamError
    {
        try {
            reader.close();
            return T;
        }
        catch (IOException e) {
            throw new StreamError(e);
        }
    }

    private int read() throws IOException
    {
        int n = reader.read();
        ++offset;
        if (n == '\n')
            ++lineNumber;
        return n;
    }

    private void unread(int n) throws IOException
    {
        reader.unread(n);
        --offset;
        if (n == '\n')
            --lineNumber;
    }
}
