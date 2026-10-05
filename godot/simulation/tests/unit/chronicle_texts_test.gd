extends GdUnitTestSuite
## ChronicleTexts: loading and validating the chronicle vocabulary.


func _data() -> Dictionary:
	var measures := {}
	for measure in ParamHistory.MEASURES:
		measures[String(measure)] = "{param} " + String(measure)
	return {
		"species": {"moss": "mchy"},
		"events": {"species_emerged": "Pojawiają się {species}."},
		"causes": {"fire": "pożary"},
		"measures": measures,
	}


func _errors(data: Dictionary) -> String:
	return "\n".join(ChronicleTexts.from_data(data).errors)


func test_project_vocabulary_is_valid() -> void:
	var result := ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH)
	assert_array(Array(result.errors)).is_empty()


func test_project_vocabulary_names_every_project_species() -> void:
	var texts: ChronicleTexts = ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH).value
	var catalog: SpeciesCatalog = SpeciesCatalog.load_json(SpeciesCatalog.DEFAULT_PATH).value
	for id in catalog.ids():
		assert_bool(texts.species.has(String(id))).override_failure_message("no chronicle name for species '%s'" % id).is_true()


func test_project_vocabulary_explains_every_extinction_cause() -> void:
	var texts: ChronicleTexts = ChronicleTexts.load_json(ChronicleTexts.DEFAULT_PATH).value
	for cause in BiosphereSystem.LOSS_CAUSES:
		assert_bool(texts.causes.has(String(cause))).override_failure_message("no chronicle phrase for cause '%s'" % cause).is_true()


func test_reads_valid_data() -> void:
	var texts: ChronicleTexts = ChronicleTexts.from_data(_data()).value
	assert_str(texts.species["moss"]).is_equal("mchy")
	assert_str(texts.events["species_emerged"]).is_equal("Pojawiają się {species}.")
	assert_str(texts.measures["mean"]).is_equal("{param} mean")


func test_accepts_signed_measure_phrases() -> void:
	var data := _data()
	data["measures"]["change"] = {"below": "{param} spada", "above": "{param} rośnie"}
	assert_bool(ChronicleTexts.from_data(data).is_ok()).is_true()


func test_every_measure_needs_a_phrase() -> void:
	var data := _data()
	(data["measures"] as Dictionary).erase("anomaly")
	assert_str(_errors(data)).contains("anomaly")


func test_rejects_bad_signed_phrases() -> void:
	var data := _data()
	data["measures"]["change"] = {"below": "{param} spada"}
	assert_str(_errors(data)).contains("change")
	data["measures"]["change"] = {"below": "{param} spada", "above": ""}
	assert_str(_errors(data)).contains("change")
	data["measures"]["change"] = {"below": "a", "above": "b", "level": "c"}
	assert_str(_errors(data)).contains("change")


func test_rejects_empty_or_non_text_entries() -> void:
	var data := _data()
	data["species"]["moss"] = ""
	data["events"]["species_emerged"] = 3
	var errors := _errors(data)
	assert_str(errors).contains("moss")
	assert_str(errors).contains("species_emerged")


func test_reports_all_errors_at_once() -> void:
	var result := ChronicleTexts.from_data({})
	assert_bool(result.is_ok()).is_false()
	assert_int(result.errors.size()).is_greater_equal(4)
