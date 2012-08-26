/*
 * Copyright (C) 2012  NSFW@romraider.forum and Dale C. Schultz
 * RomRaider member ID: NSFW and dschultz
 *
 * You are free to use this script for any purpose, but please keep
 * notice of where it came from!
 */
 
using System;
using System.IO;
using System.Collections.Generic;
//using System.Linq;
using System.Text;
using System.Xml;
using System.Xml.XPath;

namespace NSFW.XmlToIdc
{
    class Program
    {
        private static HashSet<string> names = new HashSet<string>();

        static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                Usage();
                return;
            }

            if (CategoryIs(args, "tables"))
            {
                if (args.Length != 2)
                {
                    UsageTables();
                }
                else
                {
                    DefineTables(args[1]);
                }
            }
            else if (CategoryIs(args, "stdparam"))
            {
                if (args.Length != 4)
                {
                    UsageStdParam();
                }
                else
                {
                    DefineStandardParameters(args[1], args[2], args[3]);
                }
            }
            else if (CategoryIs(args, "extparam"))
            {
                if (args.Length != 3)
                {
                    UsageExtParam();
                    return;
                }
                else
                {
                    DefineExtendedParameters(args[1], args[2]);
                }
            }
        }

        #region DefineXxxx functions

        private static void DefineTables(string calId)
        {
            if (!File.Exists("ecu_defs.xml"))
            {
                Console.Write("Error: ecu_defs.xml must be in the current directory.");
                return;
            }
            calId = calId.ToUpper();

            string functionName = "Tables_" + calId;
            WriteHeader(functionName, "Table definitions for " + calId);
            WriteTableNames(calId);
            WriteFooter(functionName);
        }

        private static void DefineStandardParameters(string target, string calId, string ssmBaseString)
        {
            if (!File.Exists("logger.xml"))
            {
                Console.Write("Error: logger.xml must be in the current directory.");
                return;
            }

            if (!File.Exists("logger.dtd"))
            {
                Console.Write("Error: logger.dtd must be in the current directory.");
                return;
            }

            calId = calId.ToUpper();
            ssmBaseString = ssmBaseString.ToUpper();
            uint ssmBase = uint.Parse(ssmBaseString, System.Globalization.NumberStyles.HexNumber);

            string functionName = "StdParams_" + calId;
            WriteHeader(functionName, "Standard parameter definitions for " + target.ToUpper() + ": " + calId + " with SSM read vector base " + ssmBaseString);
            WriteStandardParameters(target, calId, ssmBase);
            WriteFooter(functionName);
        }

        private static void DefineExtendedParameters(string target, string ecuId)
        {
            if (!File.Exists("logger.xml"))
            {
                Console.Write("Error: logger.xml must be in the current directory.");
                return;
            }

            if (!File.Exists("logger.dtd"))
            {
                Console.Write("Error: logger.dtd must be in the current directory.");
                return;
            }

            ecuId = ecuId.ToUpper();

            string functionName = "ExtParams_" + ecuId;
            WriteHeader(functionName, "Extended parameter definitions for " + target.ToUpper() + ": " + ecuId);
            WriteExtendedParameters(target, ecuId);
            WriteFooter(functionName);
        }

        #endregion

        private static string WriteTableNames(string xmlId)
        {
            Console.WriteLine("auto referenceAddress;");

            string ecuid = null;
            using (Stream stream = File.OpenRead("ecu_defs.xml"))
            {
                XPathDocument doc = new XPathDocument(stream);
                XPathNavigator nav = doc.CreateNavigator();
                string path = "/roms/rom/romid[xmlid='" + xmlId + "']";
                XPathNodeIterator iter = nav.Select(path);
                iter.MoveNext();
                nav = iter.Current;
                nav.MoveToChild(XPathNodeType.Element);

                while (nav.MoveToNext())
                {
                    if (nav.Name == "ecuid")
                    {
                        ecuid = nav.InnerXml;
                        break;
                    }
                }

                if (string.IsNullOrEmpty(ecuid))
                {
                    Console.WriteLine("Could not find definition for " + xmlId);
                    return null;
                }

                nav.MoveToParent();
                while (nav.MoveToNext())
                {
                    if (nav.Name == "table")
                    {
                        Console.WriteLine();

                        string name = nav.GetAttribute("name", "");
                        string storageAddress = nav.GetAttribute("storageaddress", "");

                        name = ConvertName(name);
                        MakeName(storageAddress, name);

                        List<string> axes = new List<string>();
                        if (nav.HasChildren)
                        {
                            nav.MoveToChild(XPathNodeType.Element);

                            do
                            {
                                string axis = nav.GetAttribute("type", "");
                                axes.Add(axis);
                                string axisAddress = nav.GetAttribute("storageaddress", "");

                                axis = ConvertName(name + "_" + axis);
                                MakeName(axisAddress, axis);
                            } while (nav.MoveToNext());

                            if (axes.Count == 2 &&
                                (axes[0] == "X Axis" &&
                                axes[1] == "Y Axis"))
                            {
                                Console.WriteLine("referenceAddress = DfirstB(" + storageAddress + ");");
                                Console.WriteLine("if (referenceAddress > 0)");
                                Console.WriteLine("{");
                                Console.WriteLine("    referenceAddress = referenceAddress - 12;");
                                string tableName = ConvertName("Table_" + name);
                                string command = string.Format("    MakeNameEx(referenceAddress, \"{0}\", SN_CHECK);", tableName);
                                Console.WriteLine(command);
                                Console.WriteLine("}");
                                Console.WriteLine("else");
                                Console.WriteLine("{");
                                Console.WriteLine("    Message(\"No reference to " + name + "\\n\");");
                                Console.WriteLine("}");
                            }
                            else if (axes.Count == 1 &&
                                axes[0] == "Y Axis")
                            {
                                Console.WriteLine("referenceAddress = DfirstB(" + storageAddress + ");");
                                Console.WriteLine("if (referenceAddress > 0)");
                                Console.WriteLine("{");
                                Console.WriteLine("    referenceAddress = referenceAddress - 8;");
                                string tableName = ConvertName("Table_" + name);
                                string command = string.Format("    MakeNameEx(referenceAddress, \"{0}\", SN_CHECK);", tableName);
                                Console.WriteLine(command);
                                Console.WriteLine("}");
                                Console.WriteLine("else");
                                Console.WriteLine("{");
                                Console.WriteLine("    Message(\"No reference to " + name + "\\n\");");
                                Console.WriteLine("}");
                            }

                            nav.MoveToParent();
                        }
                    }
                }
            }

            return ecuid;
        }

        private static void WriteStandardParameters(string target, string ecuid, uint ssmBase)
        {
            Console.WriteLine("auto addr;");
            Console.WriteLine("");
            if (target == "ecu" | target == "ECU")
            {
                target = "2";
            }
            if (target == "tcu" | target == "TCU")
            {
                target = "1";
            }

            using (Stream stream = File.OpenRead("logger.xml"))
            {
                XPathDocument doc = new XPathDocument(stream);
                XPathNavigator nav = doc.CreateNavigator();
                string path = "/logger/protocols/protocol[@id='SSM']/parameters/parameter";
                XPathNodeIterator iter = nav.Select(path);
                string id = "";
                while (iter.MoveNext())
                {
                    XPathNavigator navigator = iter.Current;
                    if (navigator.GetAttribute("target", "") == target)
                    {
                        continue;
                    }
                    string name = navigator.GetAttribute("name", "");
                    id = navigator.GetAttribute("id", "");
                    name = name + "_" + id.Trim();
                    string pointerName = ConvertName("PtrSsmGet_" + name);
                    string functionName = ConvertName("SsmGet_" + name);

                    if (!navigator.MoveToChild("address", ""))
                    {
                        continue;
                    }

                    string addressString = iter.Current.InnerXml;
                    addressString = addressString.Substring(2);

                    uint address = uint.Parse(addressString, System.Globalization.NumberStyles.HexNumber);
                    address = address * 4;
                    address = address + ssmBase;
                    addressString = "0x" + address.ToString("X8");

                    MakeName(addressString, pointerName);

                    string getAddress = string.Format("addr = Dword({0});", addressString);
                    Console.WriteLine(getAddress);
                    MakeName("addr", functionName);
                    Console.WriteLine();
                }
                // now let's print the switch references
                path = "/logger/protocols/protocol[@id='SSM']/switches/switch";
                iter = nav.Select(path);
                string bitString = "";
                string lastAddr = "";
                uint first = 1;
                while (iter.MoveNext())
                {
                    XPathNavigator navigator = iter.Current;
                    if (navigator.GetAttribute("target", "") == target)
                    {
                        continue;
                    }
                    id = navigator.GetAttribute("id", "");
                    id = id.Replace("S", "");
                    string addr = navigator.GetAttribute("byte", "");
                    addr = addr.Substring(2);
                    if (lastAddr.Equals(addr) || first.Equals(1))
                    {
                        bitString = bitString + "_" + id.Trim();
                        first = 0;
                    }
                    else
                    {
                        bitString = PrintSwitches(bitString, lastAddr, ssmBase, id);
                    }
                    lastAddr = addr;
                }
                bitString = PrintSwitches(bitString, lastAddr, ssmBase, id);
            }
        }

        private static void WriteExtendedParameters(string target, string ecuid)
        {
            if (target == "ecu" | target == "ECU")
            {
                target = "2";
            }
            if (target == "tcu" | target == "TCU")
            {
                target = "1";
            }

            using (Stream stream = File.OpenRead("logger.xml"))
            {
                XPathDocument doc = new XPathDocument(stream);
                XPathNavigator nav = doc.CreateNavigator();
                string path = "/logger/protocols/protocol[@id='SSM']/ecuparams/ecuparam/ecu[@id='" + ecuid + "']/address";
                XPathNodeIterator iter = nav.Select(path);
                while (iter.MoveNext())
                {
                    string addressString = iter.Current.InnerXml;
                    addressString = addressString.Substring(2);
                    uint address = uint.Parse(addressString, System.Globalization.NumberStyles.HexNumber);
                    address |= 0xFF000000;
                    addressString = "0x" + address.ToString("X8");

                    XPathNavigator n = iter.Current;
                    n.MoveToParent();
                    n.MoveToParent();
                    if (n.GetAttribute("target", "") == target)
                    {
                        continue;
                    }
                    string name = n.GetAttribute("name", "");
                    string id = n.GetAttribute("id", "");
                    name = "E_" + ConvertName(name) + "_" + id.Trim();

                    MakeName(addressString, name);
                }
            }
        }

        #region Utility functions

        private static void WriteHeader(string functionName, string description)
        {
            Console.WriteLine("///////////////////////////////////////////////////////////////////////////////");
            Console.WriteLine("// " + description);
            Console.WriteLine("///////////////////////////////////////////////////////////////////////////////");
            Console.WriteLine("#include <idc.idc>");
            Console.WriteLine("static main ()");
            Console.WriteLine("{");
        }

        private static void WriteFooter(string functionName)
        {
            Console.WriteLine("}");
        }

        private static string PrintSwitches(string bitString, string lastAddr, uint ssmBase, string id)
        {
            string name = "Switches" + bitString;
            string pointerName = ConvertName("PtrSsmGet_" + name);
            string functionName = ConvertName("SsmGet_" + name);
            uint address = uint.Parse(lastAddr, System.Globalization.NumberStyles.HexNumber);
            address = address * 4;
            address = address + ssmBase;
            string addressString = "0x" + address.ToString("X8");

            MakeName(addressString, pointerName);

            string getAddress = string.Format("addr = Dword({0});", addressString);
            Console.WriteLine(getAddress);
            MakeName("addr", functionName);
            Console.WriteLine();
            return bitString = "_" + id.Trim();
        }

        private static void MakeName(string address, string name)
        {
            string command = string.Format("MakeNameEx({0}, \"{1}\", SN_CHECK);",
                address,
                name);
            Console.WriteLine(command);
        }

        private static string ConvertName(string original)
        {
            // two brute force search and replace sequences for trailing spaces in names
            // another option is to just convert all " " to _
            //if (original.EndsWith("  "))
            //{
            //    int lastLocation = original.LastIndexOf("  ");

            //    if (lastLocation >= 0)
            //        original = original.Substring(0, lastLocation) + "__";
            //}

            //if (original.EndsWith(" "))
            //{
            //    int lastLocation = original.LastIndexOf(" ");

            //    if (lastLocation >= 0)
            //        original = original.Substring(0, lastLocation) + "_";
            //}
            original = original.Replace(")(", "_");

            StringBuilder builder = new StringBuilder(original.Length);
            foreach (char c in original)
            {
                if (char.IsLetterOrDigit(c))
                {
                    builder.Append(c);
                    continue;
                }

                if (c == '_')
                {
                    builder.Append(c);
                    continue;
                }

                if (char.IsWhiteSpace(c))
                {
                    builder.Append('_');
                    continue;
                }

                if (c == '*')
                {
                    builder.Append("Ext");
                    continue;
                }
            }

            // Make sure it's unique
            string name = builder.ToString();
            while (names.Contains(name))
            {
                name = name + "_";
            }
            names.Add(name);

            return name;
        }

        private static bool CategoryIs(string[] args, string category)
        {
            return string.Compare(args[0], category, StringComparison.OrdinalIgnoreCase) == 0;
        }

        #endregion

        #region Usage instructions

        private static void Usage()
        {
            Console.WriteLine("XmlToIdc Usage:");
            Console.WriteLine("XmlToIdc.exe <category> ...");
            Console.WriteLine();
            Console.WriteLine("Where <category> is one of the following:");
            Console.WriteLine("    tables <cal-id>");
            Console.WriteLine("    stdparam <target> <cal-id> <ssm-base>");
            Console.WriteLine("    extparam <target> <ecu-id>");
            Console.WriteLine();
            Console.WriteLine("target: Car control module, e.g. ecu for engine control unit or tcu for transmission control unit");
            Console.WriteLine("ecu-id: ECU identifier, e.g. 2F12785606");
            Console.WriteLine("cal-id: Calibration id, e.g. A2WC522N");
            Console.WriteLine("ssm-base: Base address of the SSM 'read' vector, e.g. 4EDDC");
            Console.WriteLine();
            Console.WriteLine("And you'll want to redirect stdout to a file, like:");
            Console.WriteLine("XmlToIdc.exe ... > Whatever.idc");
        }

        private static void UsageTables()
        {
            Console.WriteLine("XmlToIdc Usage:");
            Console.WriteLine("XmlToIdc.exe tables <cal-id>");
            Console.WriteLine();
            Console.WriteLine("cal-id: Calibration id, e.g. A2WC522N");
            Console.WriteLine();
            Console.WriteLine("And you'll want to redirect stdout to a file, like:");
            Console.WriteLine("XmlToIdc.exe tables A2WC522N > Tables.idc");
        }

        private static void UsageStdParam()
        {
            Console.WriteLine("StdParam Usage:");
            Console.WriteLine("XmlToIdc.exe stdparam <target> <cal-id> <ssm-base>");
            Console.WriteLine();
            Console.WriteLine("target: Car control module, e.g. tcu for transmission control unit");
            Console.WriteLine("cal-id: Calibration id, e.g. A2WC522N");
            Console.WriteLine("ssm-base: Base address of the SSM 'read' vector, e.g. 4EDDC");
            Console.WriteLine();
            Console.WriteLine("And you'll want to redirect stdout to a file, like:");
            Console.WriteLine("XmlToIdc.exe stdparam tcu A2WC522N 4EDDC > StdParam.idc");
        }

        private static void UsageExtParam()
        {
            Console.WriteLine("ExtParam Usage:");
            Console.WriteLine("XmlToIdc.exe extparam <target> <ecu-id>");
            Console.WriteLine();
            Console.WriteLine("target: Car control module, e.g. ecu for engine control unit");
            Console.WriteLine("ecu-id: ECU identifier, e.g. 2F12785606");
            Console.WriteLine();
            Console.WriteLine("And you'll want to redirect stdout to a file, like:");
            Console.WriteLine("XmlToIdc.exe extparam ecu 2F12785606 > ExtParam.idc");
        }

        #endregion
    }
}
