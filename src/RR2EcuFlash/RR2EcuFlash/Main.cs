/*
 * Copyright (C) 2012  Dale C. Schultz
 * RomRaider member ID: dschultz
 *
 * You are free to use this source for any purpose, but please keep
 * notice of where it came from!
 *
 * Purpose:
 *     to convert a RomRaider Editor definition to an EcuFlash definition
 */

using System;
using System.Text;
using System.Windows.Forms;
using System.IO;
using System.Xml;
using System.Xml.XPath;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Reflection;

namespace RR2EcuFlash
{
    class MainClass
    {
        private static HashSet<string> stateNames = new HashSet<string>();

        public static void Main (string[] args)
        {
            if (args.Length != 2)
            {
                Usage();
                return;
            }
            ConvertDef(args);
        }

        private static void ConvertDef(string[] args)
        {
            string filename = args[0];
            string calId = args[1];

            if (!File.Exists(filename))
            {
                MessageBox.Show("'" + filename + "' was not found. Check your path and spelling.",
                                "Error - File Missing",
                                MessageBoxButtons.OK,
                                MessageBoxIcon.Exclamation,
                                MessageBoxDefaultButton.Button1);
                return;
            }

            using (Stream stream = File.OpenRead(filename))
            {
                IDictionary<string, string> romidElements = new Dictionary<string, string>();
                romidElements.Add("rombase","");
                romidElements.Add("xmlid","");
                romidElements.Add("internalidaddress","");
                romidElements.Add("internalidstring","");
                romidElements.Add("caseid","");
                romidElements.Add("ecuid","");
                romidElements.Add("year","");
                romidElements.Add("market","");
                romidElements.Add("make","");
                romidElements.Add("model","");
                romidElements.Add("submodel","");
                romidElements.Add("transmission","");
                romidElements.Add("memmodel","");
                romidElements.Add("flashmethod","");
                romidElements.Add("obsolete","");
                XPathDocument doc = new XPathDocument(stream);
                XPathNavigator nav = doc.CreateNavigator();
                string path = "/roms/rom/romid[xmlid='" + calId + "']";
                string currentTable = "";

                XPathNodeIterator iter = nav.Select(path);
                iter.MoveNext();
                nav = iter.Current;    // this is the romid element

                // read through all of the child elements of romid
                if (nav.HasChildren)
                {
                    nav.MoveToFirstChild();
                    do
                    {
                        switch (nav.Name)
                        {
                        case "xmlid":
                            romidElements["xmlid"] = nav.InnerXml;
                            break;
                        case "internalidaddress":
                            romidElements["internalidaddress"] = nav.InnerXml;
                            break;
                        case "internalidstring":
                            romidElements["internalidstring"] = nav.InnerXml;
                            break;
                        case "caseid":
                            romidElements["caseid"] = nav.InnerXml;
                            break;
                        case "ecuid":
                            romidElements["ecuid"] = nav.InnerXml;
                            break;
                        case "year":
                            romidElements["year"] = nav.InnerXml;
                            break;
                        case "market":
                            romidElements["market"] = nav.InnerXml;
                            break;
                        case "make":
                            romidElements["make"] = nav.InnerXml;
                            break;
                        case "model":
                            romidElements["model"] = nav.InnerXml;
                            break;
                        case "submodel":
                            romidElements["submodel"] = nav.InnerXml;
                            break;
                        case "transmission":
                            romidElements["transmission"] = nav.InnerXml;
                            break;
                        case "memmodel":
                            romidElements["memmodel"] = nav.InnerXml;
                            break;
                        case "flashmethod":
                            romidElements["flashmethod"] = nav.InnerXml;
                            break;
                        case "obsolete":
                            romidElements["obsolete"] = nav.InnerXml;
                            break;
                        }
                    }
                    while (nav.MoveToNext());
                }

                if (string.IsNullOrEmpty(romidElements["xmlid"]))
                {
                    MessageBox.Show("Could not find definition for " + calId,
                                    "Error - Definition not found",
                                    MessageBoxButtons.OK,
                                    MessageBoxIcon.Exclamation,
                                    MessageBoxDefaultButton.Button1);
                    return;
                }

                // get the inherited base ROM ID
                do
                {
                    nav.MoveToParent();
                }
                while (nav.Name != "rom");
                if (nav.HasAttributes)
                {
                    romidElements["rombase"] = nav.GetAttribute("base", "");
                }
                string outFilename = romidElements["xmlid"].ToUpper() + ".xml";
                StreamWriter outfile = new StreamWriter(outFilename, false);

                string preamble = MakePreamble(romidElements["xmlid"]);
                outfile.Write(preamble);
                string romId = MakeRomId(romidElements);
                outfile.Write(romId);

                nav = iter.Current;    // positioned at rom element
                nav.MoveToFirstChild();    // this is the first child element of rom (i.e.: romid)
                if (nav.HasChildren)
                {
                    do
                    {
                        if (nav.Name.Equals("romid")) continue;
                        if (nav.Name.Equals("table"))
                        {
                            string name = "";
                            string dataAddr = "";
                            string xSize = "";
                            string ySize = "";
                            string type = "";
                            string axisAddr = "";
                            if (nav.HasAttributes)
                            {
                                name = nav.GetAttribute("name","");
                                currentTable = name;
                                if (name.Equals("Checksum Fix")) continue;
                                if (name.Equals("Fuel Pump Duty Cycle"))
                                {
                                    name = "Fuel Pump Duty";
                                }
                                name = Regex.Replace(name, @"  $", "__");
                                name = Regex.Replace(name, @" $", "_");

                                dataAddr = nav.GetAttribute("storageaddress","");
                                dataAddr = Regex.Replace(dataAddr, @"^0x", "");
                                dataAddr = dataAddr.ToLower();

                                xSize = nav.GetAttribute("sizex","");
                                ySize = nav.GetAttribute("sizey","");
                            }
                            string table = "";

                            if (nav.HasChildren)
                            {
                                table = string.Format("  <table name=\"{0}\" address=\"{1}\">",
                                                      name,
                                                      dataAddr);
                                outfile.WriteLine(table);

                                nav.MoveToFirstChild();    // move to first child (i.e.: table axis element)
                                do
                                {
                                    if (nav.Name.Equals("state"))
                                    {
                                        AddStateTable(currentTable);
                                        outfile.WriteLine("-- Need to define scaling element and create scaling attribute for this table --");
                                    }
                                    else
                                    {
                                        string elements = "";
                                        if (nav.HasAttributes)
                                        {
                                            type = nav.GetAttribute("type","");
                                            type = Regex.Replace(type, @"^X Axis$", "X");
                                            type = Regex.Replace(type, @"^Y Axis$", "Y");

                                            axisAddr = nav.GetAttribute("storageaddress","");
                                            axisAddr = Regex.Replace(axisAddr, @"^0x", "");
                                            axisAddr = axisAddr.ToLower();

                                            if (type.Equals("X"))
                                            {
                                                if (!string.IsNullOrEmpty(xSize))
                                                {
                                                    elements = string.Format("elements=\"{0}\" ", xSize);
                                                }
                                            }
                                            else
                                            {
                                                if (!string.IsNullOrEmpty(ySize))
                                                {
                                                    elements = string.Format("elements=\"{0}\" ", ySize);
                                                }
                                            }
                                            table = string.Format("    <table name=\"{0}\" address=\"{1}\" {2}/>",
                                                                  type,
                                                                  axisAddr,
                                                                  elements);
                                            outfile.WriteLine(table);
                                        }
                                    }
                                }
                                while (nav.MoveToNext());    // move to next table axis element

                                nav.MoveToParent();    // move back to parent table element
                                outfile.WriteLine("  </table>");
                            }
                            else if (!nav.HasChildren &&
                                     (!string.IsNullOrEmpty(xSize) || !string.IsNullOrEmpty(ySize)))
                            {
                                table = string.Format("  <table name=\"{0}\" address=\"{1}\">",
                                                      name,
                                                      dataAddr);
                                outfile.WriteLine(table);

                                if (!string.IsNullOrEmpty(xSize))
                                {
                                    table = string.Format("    <table name=\"X\" elements=\"{0}\" />", xSize);
                                    outfile.WriteLine(table);
                                }
                                if (!string.IsNullOrEmpty(ySize))
                                {
                                    table = string.Format("    <table name=\"Y\" elements=\"{0}\" />", ySize);
                                    outfile.WriteLine(table);
                                }
                                outfile.WriteLine("  </table>");
                            }
                            else
                            {
                                table = string.Format("  <table name=\"{0}\" address=\"{1}\" />",
                                                      name,
                                                      dataAddr);
                                outfile.WriteLine(table);
                            }
                        }
                    }
                    while (nav.MoveToNext());    // move to next table element
                }
                if (stateNames.Count > 0)
                {
                    outfile.WriteLine("</change to 'rom' when scalings has been fixed>");
                    MessageBox.Show("Found " + stateNames.Count + " state elements, you will need to create them manually " +
                                    "from the current and BASE def info and fix up the table entries that use " +
                                    "them.  Tables affected will now be listed on the command line.",
                                    "Warning - Definition is not complete",
                                    MessageBoxButtons.OK,
                                    MessageBoxIcon.Exclamation,
                                    MessageBoxDefaultButton.Button1);

                    Console.WriteLine();
                    Console.WriteLine("Table names that require scaling definitions to be defined from the BASE and current def:");
                    foreach (string sn in stateNames)
                    {
                        Console.WriteLine(sn);
                    }
                }
                else
                {
                    outfile.WriteLine("</rom>");
                }
                outfile.Close();
            }
        }

        private static string MakePreamble(string xmlId)
        {
            string writeTime = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss %K");
            string version = "    This file was gernerated by RR2EcuFlash version: " +
                              Assembly.GetExecutingAssembly().GetName().Version;
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
            builder.AppendLine("<!-- EcuFlash DEFINITION FILE FOR " + xmlId + " CREATED " + writeTime);
            builder.AppendLine(version);
            builder.AppendLine();
            builder.AppendLine("TERMS, CONDITIONS, AND DISCLAIMERS");
            builder.AppendLine("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
            builder.AppendLine("WARNING: These definition files are created as the result of the extremely complex and time consuming");
            builder.AppendLine("process of reverse-engineering the factory ECU. Because of this complexity, it is necessary to make certain");
            builder.AppendLine("assumptions and, therefore, it is impossible to always deal in absolutes in regards to representations made");
            builder.AppendLine("by these definitions. In addition, due to this complexity and the numerous variations among different ECUs,");
            builder.AppendLine("it is also impossible to guarantee that the definitions will not contain errors or other bugs. What this all means");
            builder.AppendLine("is that there is the potential for bugs, errors and misrepresentations which can result in damage to your motor,");
            builder.AppendLine("your ECU as well the possibility of causing your vehicle to behave unexpectedly on the road, increasing the");
            builder.AppendLine("risk of death or injury. Modifications to your vehicle's ECU may also be in violation of local, state and federal");
            builder.AppendLine("laws. By using these definition files, either directly or indirectly, you agree to assume 100% of all risk and");
            builder.AppendLine("RomRaider's creators and contributors shall not be held responsible for any damages or injuries you receive.");
            builder.AppendLine("This product is for advanced users only. There are no safeguards in place when tuning with RomRaider. As such,");
            builder.AppendLine("the potential for serious damage and injury still exists, even if the user does not experience any bugs or errors. ");
            builder.AppendLine();
            builder.AppendLine("As always, use at your own risk.");
            builder.AppendLine();
            builder.AppendLine("These definitions are created for FREE without any sort of guarantee. The developers cannot be held liable");
            builder.AppendLine("for any damage or injury incurred as a result of these definitions. USE AT YOUR OWN RISK!");
            builder.AppendLine("-->");
            return builder.ToString();
        }

        private static string MakeRomId(IDictionary<string, string> elements)
        {
            string value = "";
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("<rom>");
            builder.AppendLine("  <romid>");
            foreach (var pair in elements)
            {
                string tag = pair.Key;
                string text = pair.Value;
                if (tag.Equals("rombase")) continue;
                if (!string.IsNullOrEmpty(text))
                {
                    builder.AppendLine("    <" + tag + ">" + text + "</" + tag + ">");
                    if (tag.Equals("memmodel") && text.StartsWith("SH705"))
                    {
                        builder.AppendLine("    <checksummodule>subarudbw</checksummodule>");
                    }
                }
            }
            builder.AppendLine("  </romid>");
            if (elements.TryGetValue("rombase", out value))
            {
                builder.AppendLine("  <include>" + elements["rombase"] + "</include>");
            }
            return builder.ToString();
        }

        private static void AddStateTable(string name)
        {
            if(name.Length > 0)
            {
                if (!stateNames.Contains(name))
                {
                    stateNames.Add(name);
                }
            }
        }

        private static void Usage()
        {
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("RR2EcuFlash.exe <RomRaider Editor Def File> <CAL ID>");
            builder.AppendLine();
            MessageBox.Show(builder.ToString(), "RR2EcuFlash Usage Help");
        }
    }
}
